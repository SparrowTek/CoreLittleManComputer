import Foundation

/// One problem the assembler found, located by line and column.
public struct AssemblyDiagnostic: Hashable, Sendable {
    /// The kinds of problem the assembler reports.
    public enum Kind: Hashable, Sendable {
        /// A token in the instruction position, or alone on a line, is not a
        /// mnemonic or a number.
        case unknownMnemonic(String)
        /// A line holds only a label ending in a colon.
        case missingMnemonic(label: String)
        /// A label is not a valid identifier, or is a reserved word.
        case invalidLabel(String)
        /// A label was already defined on an earlier line.
        case duplicateLabel(String)
        /// An operand refers to a label no line defines.
        case undefinedLabel(String)
        /// An instruction that needs a mailbox was given none.
        case missingOperand(Opcode)
        /// `INP`, `OUT` or `HLT` was given an operand.
        case unexpectedOperand(Opcode)
        /// An operand is neither a number nor a valid label.
        case invalidOperand(String)
        /// A numeric mailbox operand is outside `0...99`.
        case addressOutOfRange(Int)
        /// A `DAT` value is outside `0...999`.
        case dataOutOfRange(Int)
        /// A line has more tokens than a label, a mnemonic and an operand.
        case unexpectedToken(String)
        /// The program needs more than 100 mailboxes.
        case programTooLarge
    }

    /// The one-based source line.
    public var line: Int

    /// The one-based column of the offending token.
    public var column: Int

    /// What went wrong.
    public var kind: Kind

    public init(line: Int, column: Int, kind: Kind) {
        self.line = line
        self.column = column
        self.kind = kind
    }

    /// A human-readable explanation without the location.
    public var message: String {
        switch kind {
        case .unknownMnemonic(let token):
            "'\(token)' is not an instruction."
        case .missingMnemonic(let label):
            "Label '\(label)' needs an instruction or DAT after it."
        case .invalidLabel(let label):
            "'\(label)' cannot be used as a label."
        case .duplicateLabel(let label):
            "Label '\(label)' is already defined."
        case .undefinedLabel(let label):
            "Label '\(label)' is not defined anywhere."
        case .missingOperand(let opcode):
            "\(opcode.mnemonic) needs a mailbox number or label."
        case .unexpectedOperand(let opcode):
            "\(opcode.mnemonic) does not take an operand."
        case .invalidOperand(let token):
            "'\(token)' is not a mailbox number or label."
        case .addressOutOfRange(let value):
            "Mailbox \(value) does not exist; mailboxes are numbered \(MailboxAddress.range.lowerBound) to \(MailboxAddress.range.upperBound)."
        case .dataOutOfRange(let value):
            "DAT \(value) does not fit in a mailbox; mailboxes hold \(Word.range.lowerBound) to \(Word.range.upperBound)."
        case .unexpectedToken(let token):
            "Unexpected '\(token)' after the instruction."
        case .programTooLarge:
            "The program needs more than \(MailboxAddress.count) mailboxes."
        }
    }
}

extension AssemblyDiagnostic: CustomStringConvertible {
    /// The location followed by ``message``, such as `"Line 3: 'FOO' is not an instruction."`.
    public var description: String {
        "Line \(line): \(message)"
    }
}

/// Thrown by ``Assembler/assemble(_:)`` with every problem found in the source.
///
/// Diagnostics are ordered by line so an editor can show them all at once.
public struct AssemblyError: Error, Hashable, Sendable {
    /// The problems found, ordered by line. Never empty when thrown by the assembler.
    public var diagnostics: [AssemblyDiagnostic]

    public init(diagnostics: [AssemblyDiagnostic]) {
        self.diagnostics = diagnostics
    }
}

extension AssemblyError: CustomStringConvertible, LocalizedError {
    /// Every diagnostic on its own line.
    public var description: String {
        diagnostics.map(\.description).joined(separator: "\n")
    }

    public var errorDescription: String? {
        description
    }
}
