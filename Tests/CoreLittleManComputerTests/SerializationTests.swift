#if canImport(Testing)
import Testing
import Foundation
@testable import CoreLittleManComputer

@Suite("Serialization")
struct SerializationTests {

    @Test func program_serialization_round_trip() throws {
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
        let snapshot = try JSONDecoder().decode(ProgramSnapshot.self, from: data)
        #expect(snapshot.metadata.schemaVersion == ProgramSnapshot.currentVersion)
        let decoded = try serializer.importJSON(data)

        #expect(decoded.usedRange == program.usedRange)
        for index in 0..<decoded.usedRange.upperBound {
            let address = MailboxAddress(index)
            #expect(decoded.word(at: address) == program.word(at: address))
        }
    }

    @Test func program_state_serialization_round_trip() throws {
        let program = Program(words: [Word(901), Word(902), Word.zero])
        var state = ProgramState()
        state.enqueueInbox(5)
        let engine = ExecutionEngine(program: program, initialState: state)
        try engine.step() // INP
        try engine.step() // OUT

        let serializer = ProgramStateSerializer()
        let data = try serializer.exportJSON(engine.state)
        let stateSnapshot = try JSONDecoder().decode(ProgramStateSnapshot.self, from: data)
        #expect(stateSnapshot.metadata.schemaVersion == ProgramStateSnapshot.currentVersion)
        let restored = try serializer.importJSON(data)

        #expect(restored.outbox == [5])
        #expect(restored.counter == MailboxAddress(2))
    }

    @Test func program_stores_words_with_padding() throws {
        let words = [Word(123), Word.zero]
        let program = Program(words: words, labels: ["loop": MailboxAddress(0)])
        #expect(program.usedRange == 0..<2)
        #expect(program.word(at: MailboxAddress(0)) == Word(123))
        #expect(try program.decoded(at: MailboxAddress(1)) == .instruction(try Instruction(opcode: .halt)))
        #expect(program.label(named: "loop") == MailboxAddress(0))
        #expect(program.word(at: MailboxAddress(10)) == Word.zero)
    }

    @Test func word_codable_round_trip() throws {
        let word = Word(42)
        let data = try JSONEncoder().encode(word)
        let decoded = try JSONDecoder().decode(Word.self, from: data)
        #expect(decoded == word)
    }

    @Test func mailbox_address_codable_round_trip() throws {
        let address = MailboxAddress(99)
        let data = try JSONEncoder().encode(address)
        let decoded = try JSONDecoder().decode(MailboxAddress.self, from: data)
        #expect(decoded == address)
    }

    @Test func accumulator_codable_round_trip() throws {
        let accumulator = Accumulator(-42)
        let data = try JSONEncoder().encode(accumulator)
        let decoded = try JSONDecoder().decode(Accumulator.self, from: data)
        #expect(decoded == accumulator)
    }

    @Test func word_codable_rejects_invalid() {
        let json = "1500".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Word.self, from: json)
        }
    }

    @Test func mailbox_address_codable_rejects_invalid() {
        let json = "100".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(MailboxAddress.self, from: json)
        }
    }

    @Test func accumulator_codable_rejects_invalid() {
        let json = "500".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Accumulator.self, from: json)
        }
    }
}
#endif
