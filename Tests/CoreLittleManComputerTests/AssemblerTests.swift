#if canImport(Testing)
import Testing
@testable import CoreLittleManComputer

@Suite("Assembler")
struct AssemblerTests {

    @Test func compiles_sample_program() throws {
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

    @Test func reports_unresolved_labels() {
        #expect(throws: AssemblerError.unresolvedSymbol(line: 1, symbol: "MISSING")) {
            try Assembler().assemble("LDA MISSING")
        }
    }

    @Test func rejects_duplicate_labels() {
        let source = """
        LOOP LDA ONE
        LOOP ADD ONE
        ONE DAT 1
        """
        #expect(throws: AssemblerError.duplicateLabel(line: 2, label: "LOOP")) {
            try Assembler().assemble(source)
        }
    }

    @Test func disassemble_round_trip() throws {
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

    @Test func handles_comments_and_blank_lines() throws {
        let source = """
        // This is a comment
        INP  # inline comment
        OUT  ; semicolon comment

        HLT
        """
        let program = try Assembler().assemble(source)
        #expect(program.usedRange == 0..<3)
    }

    @Test func case_insensitive_mnemonics() throws {
        let source = """
        inp
        out
        hlt
        """
        let program = try Assembler().assemble(source)
        #expect(program.usedRange == 0..<3)
    }

    @Test func rejects_trailing_tokens() {
        #expect(throws: AssemblerError.trailingTokens(line: 1)) {
            try Assembler().assemble("LDA ONE TWO")
        }
    }

    @Test func rejects_program_exceeding_capacity() {
        let lines = (0..<101).map { "DAT \($0 % 100)" }
        let source = lines.joined(separator: "\n")
        #expect(throws: AssemblerError.programTooLarge(line: 101)) {
            try Assembler().assemble(source)
        }
    }

    @Test func handles_program_at_full_capacity() throws {
        let lines = (0..<100).map { _ in "DAT 0" }
        let source = lines.joined(separator: "\n")
        let program = try Assembler().assemble(source)
        #expect(program.usedRange == 0..<100)
    }

    @Test func error_descriptions_are_human_readable() {
        let error = AssemblerError.unresolvedSymbol(line: 5, symbol: "MISSING")
        #expect(error.description.contains("Line 5"))
        #expect(error.description.contains("MISSING"))
    }
}
#endif
