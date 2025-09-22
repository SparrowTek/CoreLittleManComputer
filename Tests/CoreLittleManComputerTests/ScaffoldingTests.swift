#if canImport(Testing)
import Testing
import Foundation
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

@Test
func traceFormatterProducesReadableOutput() throws {
    let instruction = try Instruction(opcode: .add, operand: .address(MailboxAddress(5)))
    let entry = ProgramState.TraceEntry(cycle: 1,
                                        counter: MailboxAddress(2),
                                        instruction: instruction,
                                        accumulator: Accumulator(7))
    let formatter = TraceFormatter()
    let output = formatter.render([entry])
    #expect(output.contains("cycle\tcounter\topcode\taccumulator"))
    #expect(output.contains("1\t2\tADD\t7"))

    let multi = TraceFormatter(style: .multiLine, includeHeader: false).render([entry])
    #expect(multi.contains("Cycle: 1"))
    #expect(multi.contains("Instruction: ADD"))
}

@Test
func stateSnapshotFormatterSummarisesState() {
    var state = ProgramState()
    state.emitOutput(3)
    let formatter = StateSnapshotFormatter()
    let summary = formatter.render(state)
    #expect(summary.contains("Outbox: [3]"))
}

@Test
func executionEngineWrapPolicyHandlesOverflow() throws {
    let source = """
    LDA VALUE
    ADD VALUE
    OUT
    HLT
    VALUE DAT 600
    """

    let assembler = Assembler()
    let program = try assembler.assemble(source)
    let engine = ExecutionEngine(program: program, numericPolicy: .wrapModulo)

    try engine.runUntilHalt()
    #expect(engine.state.outbox.first == 200)
}

@Test
func executionEngineRunsBranchLoop() throws {
    let source = """
    LOOP LDA COUNT
    OUT
    SUB ONE
    STA COUNT
    BRP LOOP
    HLT
    COUNT DAT 2
    ONE DAT 1
    """

    let assembler = Assembler()
    let program = try assembler.assemble(source)
    let engine = ExecutionEngine(program: program)

    try engine.runUntilHalt(maxCycles: 100)
    #expect(engine.state.outbox == [2, 1, 0])
    #expect(engine.state.halted)
}

@Test
func stateStreamEmitsStates() async throws {
    let source = """
    LDA VALUE
    OUT
    HLT
    VALUE DAT 4
    """

    let assembler = Assembler()
    let program = try assembler.assemble(source)
    let engine = ExecutionEngine(program: program)

    let stream = engine.stateStream()
    var iterator = stream.makeAsyncIterator()

    let runTask = Task {
        try engine.runUntilHalt()
    }

    var observedOutboxes: [[Int]] = []
    while let state = await iterator.next() {
        observedOutboxes.append(state.outbox)
    }

    _ = try await runTask.value

    #expect(observedOutboxes.contains { $0 == [4] })
    #expect(engine.state.halted)
}

@Test
func programSerializationRoundTrip() throws {
    let source = """
    LDA ONE
    OUT
    HLT
    ONE DAT 1
    """

    let codec = ProgramTextCodec()
    let program = try codec.assemble(source)
    let serializer = ProgramSerializer(prettyPrinted: true)
    let data = try serializer.exportJSON(program)
    let decoded = try serializer.importJSON(data)

    #expect(decoded.usedRange == program.usedRange)
    for index in 0..<decoded.usedRange.upperBound {
        let address = MailboxAddress(index)
        #expect(decoded.word(at: address) == program.word(at: address))
    }
}

@Test
func programStateSerializationRoundTrip() throws {
    let program = Program(words: [Word(901), Word(902), Word.zero])
    var state = ProgramState()
    state.enqueueInbox(5)
    let engine = ExecutionEngine(program: program, initialState: state)
    try engine.step() // INP
    try engine.step() // OUT

    let serializer = ProgramStateSerializer()
    let data = try serializer.exportJSON(engine.state)
    let restored = try serializer.importJSON(data)

    #expect(restored.outbox == [5])
    #expect(restored.counter == MailboxAddress(2))
}

@Test
func assemblerDisassemblerRoundTripMaintainsText() throws {
    let source = """
    LOOP LDA COUNT
    OUT
    SUB ONE
    STA COUNT
    BRP LOOP
    HLT
    COUNT DAT 2
    ONE DAT 1
    """

    let codec = ProgramTextCodec()
    let program = try codec.assemble(source)
    let disassembly = codec.disassemble(program)
    #expect(disassembly.contains("LOOP"))
    let reassembled = try codec.assemble(disassembly)
    #expect(reassembled.usedRange == program.usedRange)
}

@Test
func executionEngineHandlesRandomAdds() throws {
    for lhs in -3...3 {
        for rhs in -3...3 {
            let source = """
            LDA A
            ADD B
            OUT
            HLT
            A DAT \(lhs)
            B DAT \(rhs)
            """
            let program = try ProgramTextCodec().assemble(source)
            let engine = ExecutionEngine(program: program)
            try engine.runUntilHalt()
            #expect(engine.state.outbox == [lhs + rhs])
        }
    }
}

@Test
func executionEnginePerformanceSmoke() throws {
    let source = """
    LOOP LDA COUNT
    SUB ONE
    STA COUNT
    BRP LOOP
    HLT
    COUNT DAT 200
    ONE DAT 1
    """

    let program = try ProgramTextCodec().assemble(source)
    let engine = ExecutionEngine(program: program)

    let start = Date()
    try engine.runUntilHalt(maxCycles: 10_000)
    let elapsed = Date().timeIntervalSince(start)

    #expect(engine.state.halted)
    #expect(engine.state.cycles <= 10_000)
    #expect(elapsed < 1.0)
}
#else
#warning("Swift Testing is unavailable; CoreLittleManComputer tests are stubs until the toolchain provides the Testing module.")
#endif
