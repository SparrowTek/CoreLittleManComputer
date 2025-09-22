#if canImport(Testing)
import Testing
@testable import CoreLittleManComputer

@Test
func wordSignedConversionRoundTrip() {
    let negativeOne = Word(signedValue: -1)
    #expect(negativeOne.rawValue == 999)
    #expect(negativeOne.signedValue == -1)

    let positive = Word(123)
    #expect(positive.signedValue == 123)
    #expect(positive.zeroPaddedString == "123")

    let padded = Word(7)
    #expect(padded.zeroPaddedString == "007")
}

@Test
func numericPolicyTrapOnOverflowThrows() {
    let policy = NumericPolicy.trapOnOverflow
    do {
        _ = try policy.accumulator(from: 600)
        Issue.record("Expected overflow")
    } catch let error as NumericError {
        #expect(error == .overflow(value: 600))
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test
func numericPolicyWrapModuloProducesSignedValue() throws {
    let policy = NumericPolicy.wrapModulo
    let accumulator = try policy.accumulator(from: 600)
    #expect(accumulator.value == -400)

    let word = try policy.word(fromSigned: -1)
    #expect(word.rawValue == 999)
}

@Test
func instructionEncodingAndDecodingRoundTrip() throws {
    let address = MailboxAddress(23)
    let instruction = try Instruction(opcode: .add, operand: .address(address))
    let encoded = try InstructionWord.encode(instruction)
    #expect(encoded.rawValue == 123)

    let decoded = try InstructionWord(encoded).decode()
    guard case let .instruction(decodedInstruction) = decoded else {
        Issue.record("expected instruction")
        return
    }
    #expect(decodedInstruction == instruction)
}

@Test
func instructionDecodingOfLiterals() throws {
    let literalWord = Word(signedValue: -1)
    let decoded = try InstructionWord(literalWord).decode()
    guard case let .data(word) = decoded else {
        Issue.record("expected data literal")
        return
    }
    #expect(word == literalWord)

    let dataInstruction = try Instruction(opcode: .data, operand: .literal(-1))
    let encoded = try InstructionWord.encode(dataInstruction)
    #expect(encoded.rawValue == 999)
}

@Test
func programStoresWordsWithPadding() throws {
    let words = [Word(123), Word.zero]
    let program = Program(words: words, labels: ["loop": MailboxAddress(0)])
    #expect(program.usedRange == 0..<2)
    #expect(program.word(at: MailboxAddress(0)) == Word(123))
    #expect(try program.decoded(at: MailboxAddress(1)) == .instruction(try Instruction(opcode: .halt)))
    #expect(program.label(named: "loop") == MailboxAddress(0))
    #expect(program.word(at: MailboxAddress(10)) == Word.zero)
}

@Test
func programStateTraceRecordsEntries() throws {
    var state = ProgramState()
    let instruction = try Instruction(opcode: .halt)
    state.record(instruction: instruction)
    #expect(state.lastInstruction == instruction)
    #expect(state.trace.count == 1)
    #expect(state.trace.first?.instruction == instruction)

    state.emitOutput(3)
    state.emitOutput(7)
    #expect(state.outbox == [3, 7])
    state.clearOutputs()
    #expect(state.outbox.isEmpty)
}

@Test
func assemblerCompilesSampleProgram() throws {
    let source = """
    LDA ONE
    ADD TEN
    OUT
    ADD THREE
    OUT
    HLT
    ONE DAT 1
    TEN DAT 10
    THREE DAT 3
    """

    let assembler = Assembler()
    let program = try assembler.assemble(source)

    let expected = [506, 107, 902, 108, 902, 0, 1, 10, 3]
    for (index, value) in expected.enumerated() {
        let address = MailboxAddress(index)
        #expect(program.word(at: address).rawValue == value)
    }

    #expect(program.label(named: "ONE") == MailboxAddress(6))
    if let location = program.sourceLocation(for: MailboxAddress(0)) {
        #expect(location.line == 1)
    }

    let disassembled = Assembler().disassemble(program)
    #expect(disassembled.contains("LDA ONE"))
}

@Test
func assemblerReportsUnresolvedLabels() {
    let source = "LDA MISSING"
    let assembler = Assembler()
    do {
        _ = try assembler.assemble(source)
        Issue.record("Expected unresolved symbol error")
    } catch let error as AssemblerError {
        switch error {
        case .unresolvedSymbol(let line, let symbol):
            #expect(line == 1)
            #expect(symbol == "MISSING")
        default:
            Issue.record("Unexpected error: \(error)")
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test
func assemblerRejectsDuplicateLabels() {
    let source = """
    LOOP LDA ONE
    LOOP ADD ONE
    ONE DAT 1
    """

    let assembler = Assembler()
    do {
        _ = try assembler.assemble(source)
        Issue.record("Expected duplicate label error")
    } catch let error as AssemblerError {
        switch error {
        case .duplicateLabel(let line, let label):
            #expect(line == 2)
            #expect(label == "LOOP")
        default:
            Issue.record("Unexpected error: \(error)")
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test
func executionEngineHandlesInputOutput() throws {
    let source = """
    INP
    OUT
    HLT
    """

    let assembler = Assembler()
    let program = try assembler.assemble(source)

    let initialState = ProgramState(inbox: [42])
    let engine = ExecutionEngine(program: program, initialState: initialState)

    try engine.step() // INP
    #expect(engine.state.accumulator.value == 42)
    #expect(engine.state.counter == MailboxAddress(1))

    try engine.step() // OUT
    #expect(engine.state.outbox == [42])
    #expect(engine.state.counter == MailboxAddress(2))

    try engine.step() // HLT
    #expect(engine.state.halted)

    do {
        try engine.step()
        Issue.record("Expected halted error")
    } catch let error as ExecutionError {
        #expect(error == .halted)
    }
}

@Test
func executionEngineStoresAccumulatorIntoMemory() throws {
    let source = """
    LDA TEN
    STA RESULT
    HLT
    TEN DAT 5
    RESULT DAT 0
    """

    let assembler = Assembler()
    let program = try assembler.assemble(source)

    let engine = ExecutionEngine(program: program)
    try engine.step() // LDA TEN
    #expect(engine.state.accumulator.value == 5)

    try engine.step() // STA RESULT
    let resultAddress = MailboxAddress(4)
    #expect(engine.state.word(at: resultAddress).rawValue == 5)

    try engine.step() // HLT
    #expect(engine.state.halted)
}

@Test
func executionEngineRunUntilHaltCompletes() throws {
    let source = """
    LDA VALUE
    OUT
    HLT
    VALUE DAT 7
    """

    let assembler = Assembler()
    let program = try assembler.assemble(source)
    let engine = ExecutionEngine(program: program)

    try engine.runUntilHalt()
    #expect(engine.state.halted)
    #expect(engine.state.outbox == [7])
}

@Test
func executionEngineBreakpointStopsStep() throws {
    let source = """
    LDA ONE
    ADD ONE
    HLT
    ONE DAT 1
    """

    let assembler = Assembler()
    let program = try assembler.assemble(source)
    let engine = ExecutionEngine(program: program)
    engine.addBreakpoint(MailboxAddress(1))

    do {
        try engine.step()
        Issue.record("Expected breakpoint hit")
    } catch ExecutionError.breakpointHit(let address) {
        #expect(address == MailboxAddress(1))
    }
}

@Test
func executionEngineAsyncRunStopsOnBreakpoint() async throws {
    let source = """
    LDA ONE
    ADD ONE
    OUT
    BRA END
    ONE DAT 1
    END HLT
    """

    let assembler = Assembler()
    let program = try assembler.assemble(source)
    let engine = ExecutionEngine(program: program)
    engine.addBreakpoint(MailboxAddress(3))

    do {
        try await engine.run(schedule: .unlimited)
        Issue.record("Expected breakpoint during async run")
    } catch ExecutionError.breakpointHit(let address) {
        #expect(address == MailboxAddress(3))
    }
}

@Test
func executionEngineEventStreamPublishesEvents() async throws {
    let source = """
    INP
    OUT
    HLT
    """

    let assembler = Assembler()
    let program = try assembler.assemble(source)
    let engine = ExecutionEngine(program: program, initialState: ProgramState(inbox: [9]))

    let eventTask = Task {
        try engine.step()
        try engine.step()
    }

    var iterator = engine.events.makeAsyncIterator()
    var seenInstructionDecoded = false
    var seenOutput = false

    while let event = await iterator.next() {
        switch event {
        case .instructionDecoded(let instruction):
            if instruction.opcode == .output {
                seenInstructionDecoded = true
            }
        case .outputProduced(let value):
            seenOutput = value == 9
        case .cycleCompleted:
            if seenInstructionDecoded && seenOutput {
                break
            }
        default:
            break
        }
        if seenInstructionDecoded && seenOutput {
            break
        }
    }

    #expect(seenInstructionDecoded)
    #expect(seenOutput)
    try await eventTask.value
}
#else
#warning("Swift Testing is unavailable; CoreLittleManComputer tests are stubs until the toolchain provides the Testing module.")
#endif
