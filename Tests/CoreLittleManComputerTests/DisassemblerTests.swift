import Testing
@testable import CoreLittleManComputer

@Suite("Disassembler")
struct DisassemblerTests {
    private let assembler = Assembler()
    private let disassembler = Disassembler()

    @Test func rendersLabelsInAnAlignedColumn() throws {
        let program = try assembler.assemble(SamplePrograms.countdown.source)
        let expected = """
             INP
             OUT
        LOOP BRZ QUIT
             SUB ONE
             OUT
             BRA LOOP
        QUIT HLT
        ONE  DAT 1
        """
        #expect(disassembler.disassemble(program) == expected)
    }

    @Test func omitsTheLabelColumnWhenNothingIsLabelled() throws {
        let program = try assembler.assemble("INP\nOUT\nHLT")
        #expect(disassembler.disassemble(program) == "INP\nOUT\nHLT")
    }

    @Test func writesUnlabelledOperandsAsTwoDigitAddresses() throws {
        let program = try assembler.assemble("ADD 5\nSTA 42\nHLT")
        #expect(disassembler.disassemble(program) == "ADD 05\nSTA 42\nHLT")
    }

    @Test func keepsDataAsDataEvenWhenItLooksLikeAnInstruction() throws {
        let program = try assembler.assemble("LDA X\nHLT\nX DAT 105")
        #expect(disassembler.disassemble(program) == "  LDA X\n  HLT\nX DAT 105")
    }

    @Test func rendersRawMemoryUpToTheLastNonZeroWord() throws {
        let program = try #require(Program(words: [901, 902, 42, 400, 0]))
        #expect(disassembler.disassemble(program) == "INP\nOUT\nDAT 42\nDAT 400")
        #expect(disassembler.disassemble(program.memory) == "INP\nOUT\nDAT 42\nDAT 400")
    }

    @Test func rendersAnEmptyProgramAsNothing() {
        #expect(disassembler.disassemble(Program.empty) == "")
        #expect(disassembler.disassemble(Memory.empty) == "")
    }

    @Test(arguments: SamplePrograms.all)
    func roundTripsEverySample(sample: SampleProgram) throws {
        let original = try assembler.assemble(sample.source)
        let reassembled = try assembler.assemble(disassembler.disassemble(original))
        #expect(reassembled.memory == original.memory)
        #expect(reassembled.lines.map(\.label) == original.lines.map(\.label))
        #expect(reassembled.lines.map(\.kind) == original.lines.map(\.kind))
    }

    @Test func roundTripsEveryFormOfData() throws {
        let source = """
        LDA PTR
        HLT
        EMPTY DAT
        MAX DAT 999
        PTR DAT MAX
        42
        LABELLED 7
        """
        let original = try assembler.assemble(source)
        let reassembled = try assembler.assemble(disassembler.disassemble(original))
        #expect(reassembled.memory == original.memory)
        #expect(reassembled.labels == original.labels)
    }
}
