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
#else
#warning("Swift Testing is unavailable; CoreLittleManComputer tests are stubs until the toolchain provides the Testing module.")
#endif
