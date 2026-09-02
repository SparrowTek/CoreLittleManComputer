import Testing
@testable import CoreLittleManComputer

@Suite("Assembler")
struct AssemblerTests {
    private let assembler = Assembler()

    private func words(_ source: String) throws -> [Word] {
        let program = try assembler.assemble(source)
        return program.lines.map { program.memory[$0.address] }
    }

    private func diagnostics(_ source: String) -> [AssemblyDiagnostic] {
        do {
            _ = try assembler.assemble(source)
            return []
        } catch {
            return error.diagnostics
        }
    }

    // MARK: Encoding

    @Test func assemblesTheWikipediaSubtractionExample() throws {
        let program = try assembler.assemble(SamplePrograms.subtractTwoNumbers.source)
        #expect(program.lines.map { program.memory[$0.address] } == [901, 308, 901, 309, 508, 209, 902, 0, 0, 0])
        #expect(program.length == 10)
        #expect(program.labels == ["FIRST": 8, "SECOND": 9])
        #expect(program.lines.map(\.kind) == Array(repeating: .instruction, count: 8) + [.data, .data])
        #expect(program.memory.lastOccupiedAddress == 6)
    }

    @Test func assemblesTheWikipediaCountdownExample() throws {
        #expect(try words(SamplePrograms.countdown.source) == [901, 902, 706, 207, 902, 602, 0, 1])
    }

    @Test func encodesEveryOpcode() throws {
        let source = """
        ADD 1
        SUB 2
        STA 3
        LDA 4
        BRA 5
        BRZ 6
        BRP 7
        INP
        OUT
        HLT
        """
        #expect(try words(source) == [101, 202, 303, 504, 605, 706, 807, 901, 902, 0])
    }

    @Test func acceptsNumericAddressesAcrossTheWholeRange() throws {
        #expect(try words("ADD 0\nADD 99\nSTA 07") == [100, 199, 307])
    }

    @Test func acceptsAliasesAndAnyCase() throws {
        #expect(try words("sto 5\nCob\ninp\nOut\nhLt") == [305, 0, 901, 902, 0])
    }

    @Test func matchesLabelsWithoutRegardToCase() throws {
        let program = try assembler.assemble("Loop BRA LOOP\nBRA loop")
        #expect(program.memory[0] == 600)
        #expect(program.memory[1] == 600)
        #expect(program.labels == ["Loop": 0])
        #expect(program.address(ofLabel: "LOOP") == 0)
        #expect(program.address(ofLabel: "loop") == 0)
        #expect(program.label(at: 0) == "Loop")
        #expect(program.label(at: 1) == nil)
    }

    @Test func acceptsLabelsWithTrailingColons() throws {
        let program = try assembler.assemble("start: INP\nBRA start")
        #expect(program.labels == ["start": 0])
        #expect(program.memory[1] == 600)
    }

    @Test func ignoresCommentsAndBlankLines() throws {
        let source = """
        // A full-line comment
            ; another
        # and another
        INP   // trailing comment
        OUT ; trailing comment

        HLT # trailing comment
        """
        #expect(try words(source) == [901, 902, 0])
    }

    @Test func acceptsWindowsLineEndingsAndTabs() throws {
        #expect(try words("INP\r\n\tOUT\r\nHLT\r\n") == [901, 902, 0])
    }

    @Test func recordsSourceLinesForEveryMailbox() throws {
        let program = try assembler.assemble("\n// comment\nINP\n\nX HLT\n")
        #expect(program.lines.map(\.sourceLine) == [3, 5])
        #expect(program.sourceLine(at: 1) == 5)
        #expect(program.address(ofSourceLine: 5) == 1)
        #expect(program.address(ofSourceLine: 4) == nil)
        #expect(program.line(at: 1) == Program.Line(address: 1, kind: .instruction, label: "X", sourceLine: 5))
    }

    @Test func supportsEveryFormOfData() throws {
        let source = """
        LDA PTR
        HLT
        EMPTY DAT
        MAX DAT 999
        PTR DAT MAX
        42
        LABELLED 7
        """
        #expect(try words(source) == [504, 0, 0, 999, 3, 42, 7])
        let program = try assembler.assemble(source)
        #expect(program.lines.map(\.kind) == [.instruction, .instruction, .data, .data, .data, .data, .data])
        #expect(program.labels["LABELLED"] == 6)
    }

    @Test func fillsAllOneHundredMailboxes() throws {
        let program = try assembler.assemble(Array(repeating: "DAT 1", count: 100).joined(separator: "\n"))
        #expect(program.length == 100)
        #expect(program.memory.words.allSatisfy { $0 == 1 })
    }

    @Test func assemblesEmptySourceToAnEmptyProgram() throws {
        let program = try assembler.assemble("")
        #expect(program == .empty)
        #expect(try assembler.assemble("   \n\n// nothing\n") == .empty)
    }

    // MARK: Diagnostics

    @Test func reportsUnknownInstructions() {
        #expect(diagnostics("LOOP FOO 5") == [AssemblyDiagnostic(line: 1, column: 6, kind: .unknownMnemonic("FOO"))])
        #expect(diagnostics("INP\nOUTT") == [AssemblyDiagnostic(line: 2, column: 1, kind: .unknownMnemonic("OUTT"))])
    }

    @Test func reportsALabelWithNothingAfterIt() {
        #expect(diagnostics("LOOP:") == [AssemblyDiagnostic(line: 1, column: 1, kind: .missingMnemonic(label: "LOOP"))])
    }

    @Test func reportsInvalidLabels() {
        #expect(diagnostics("1ST INP") == [AssemblyDiagnostic(line: 1, column: 1, kind: .invalidLabel("1ST"))])
        #expect(diagnostics("ADD: INP") == [AssemblyDiagnostic(line: 1, column: 1, kind: .invalidLabel("ADD:"))])
        #expect(diagnostics("A-B INP") == [AssemblyDiagnostic(line: 1, column: 1, kind: .invalidLabel("A-B"))])
    }

    @Test func reportsDuplicateLabels() {
        #expect(diagnostics("X DAT\nx DAT") == [AssemblyDiagnostic(line: 2, column: 1, kind: .duplicateLabel("x"))])
    }

    @Test func reportsUndefinedLabels() {
        #expect(diagnostics("BRA NOWHERE\nHLT") == [AssemblyDiagnostic(line: 1, column: 5, kind: .undefinedLabel("NOWHERE"))])
        #expect(diagnostics("DAT MISSING") == [AssemblyDiagnostic(line: 1, column: 5, kind: .undefinedLabel("MISSING"))])
    }

    @Test func reportsMissingOperands() {
        #expect(diagnostics("ADD") == [AssemblyDiagnostic(line: 1, column: 1, kind: .missingOperand(.add))])
        #expect(diagnostics("X   BRA") == [AssemblyDiagnostic(line: 1, column: 5, kind: .missingOperand(.branchAlways))])
    }

    @Test func reportsUnexpectedOperands() {
        #expect(diagnostics("INP 5") == [AssemblyDiagnostic(line: 1, column: 5, kind: .unexpectedOperand(.input))])
        #expect(diagnostics("HLT X") == [AssemblyDiagnostic(line: 1, column: 5, kind: .unexpectedOperand(.halt))])
    }

    @Test func reportsOperandsThatAreNeitherNumbersNorLabels() {
        #expect(diagnostics("ADD 5X") == [AssemblyDiagnostic(line: 1, column: 5, kind: .invalidOperand("5X"))])
        #expect(diagnostics("ADD INP") == [AssemblyDiagnostic(line: 1, column: 5, kind: .invalidOperand("INP"))])
        #expect(diagnostics("DAT a.b") == [AssemblyDiagnostic(line: 1, column: 5, kind: .invalidOperand("a.b"))])
    }

    @Test func reportsAddressesOutsideTheMachine() {
        #expect(diagnostics("ADD 100") == [AssemblyDiagnostic(line: 1, column: 5, kind: .addressOutOfRange(100))])
        #expect(diagnostics("LDA -1") == [AssemblyDiagnostic(line: 1, column: 5, kind: .addressOutOfRange(-1))])
    }

    @Test func reportsDataThatDoesNotFitAMailbox() {
        #expect(diagnostics("DAT 1000") == [AssemblyDiagnostic(line: 1, column: 5, kind: .dataOutOfRange(1_000))])
        #expect(diagnostics("DAT -1") == [AssemblyDiagnostic(line: 1, column: 5, kind: .dataOutOfRange(-1))])
        #expect(diagnostics("1000") == [AssemblyDiagnostic(line: 1, column: 1, kind: .dataOutOfRange(1_000))])
    }

    @Test func reportsExtraTokens() {
        #expect(diagnostics("ADD 5 6") == [AssemblyDiagnostic(line: 1, column: 7, kind: .unexpectedToken("6"))])
        #expect(diagnostics("X DAT 1 2 3") == [AssemblyDiagnostic(line: 1, column: 9, kind: .unexpectedToken("2"))])
    }

    @Test func reportsProgramsThatDoNotFitOnce() {
        let source = Array(repeating: "DAT", count: 103).joined(separator: "\n")
        #expect(diagnostics(source) == [AssemblyDiagnostic(line: 101, column: 1, kind: .programTooLarge)])
    }

    @Test func collectsEveryProblemInLineOrder() {
        let source = """
        BRA MISSING
        INP 3
        X DAT
        X DAT
        """
        #expect(diagnostics(source) == [
            AssemblyDiagnostic(line: 1, column: 5, kind: .undefinedLabel("MISSING")),
            AssemblyDiagnostic(line: 2, column: 5, kind: .unexpectedOperand(.input)),
            AssemblyDiagnostic(line: 4, column: 1, kind: .duplicateLabel("X")),
        ])
    }

    @Test func keepsLaterLinesMeaningfulAfterAnError() {
        // The bad line still occupies a mailbox, so END resolves and is not
        // reported as a second, misleading problem.
        #expect(diagnostics("FOO\nBRA END\nEND HLT") == [AssemblyDiagnostic(line: 1, column: 1, kind: .unknownMnemonic("FOO"))])
    }

    @Test func describesProblemsForPeople() {
        let error = AssemblyError(diagnostics: [
            AssemblyDiagnostic(line: 2, column: 5, kind: .undefinedLabel("MISSING")),
            AssemblyDiagnostic(line: 4, column: 1, kind: .programTooLarge),
        ])
        #expect(error.description == "Line 2: Label 'MISSING' is not defined anywhere.\nLine 4: The program needs more than 100 mailboxes.")
        #expect(error.errorDescription == error.description)
        #expect(AssemblyDiagnostic(line: 1, column: 5, kind: .dataOutOfRange(-1)).message.contains("0 to 999"))
        #expect(AssemblyDiagnostic(line: 1, column: 5, kind: .addressOutOfRange(100)).message.contains("0 to 99"))
    }

    @Test func throwsTypedErrors() {
        let error = #expect(throws: AssemblyError.self) {
            try assembler.assemble("ADD")
        }
        #expect(error?.diagnostics.count == 1)
    }
}
