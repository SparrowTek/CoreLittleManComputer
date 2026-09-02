/// Translates Little Man Computer assembly into a ``Program``.
///
/// ## Syntax
///
/// Each line holds at most one statement of the form
/// `[label] mnemonic [operand]`. Everything after `//`, `;` or `#` is a
/// comment. Blank lines are ignored.
///
/// - Mnemonics are `ADD`, `SUB`, `STA` (or `STO`), `LDA`, `BRA`, `BRZ`,
///   `BRP`, `INP`, `OUT`, `HLT` (or `COB`) and `DAT`, in any case.
/// - A label is a name starting with a letter or underscore, optionally
///   followed by a colon. Labels are matched without regard to case, so
///   `loop` and `LOOP` are the same label, and a label may not be a mnemonic.
/// - The operand of an addressed instruction is a mailbox number `0...99`
///   or a label. `DAT` takes an optional value `0...999` or a label, whose
///   address becomes the value; with no operand the mailbox holds `000`.
/// - A line consisting only of a number `0...999` is shorthand for `DAT`,
///   so numeric listings can be pasted directly.
///
/// The assembler reports every problem it finds in one ``AssemblyError``.
public struct Assembler: Sendable {
    public init() {}

    /// Assembles `source` into a program that starts at mailbox `00`.
    public func assemble(_ source: String) throws(AssemblyError) -> Program {
        var parser = Parser()
        let lines = source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        for (offset, line) in lines.enumerated() {
            parser.parse(line, number: offset + 1)
        }
        return try parser.finish()
    }
}

// MARK: - Parsing

private struct Token {
    let text: Substring
    let column: Int
}

private enum Operand {
    case none
    case number(Int)
    case symbol(String, Token)
}

private enum Statement {
    case instruction(Opcode, Operand)
    case data(Operand)
    case invalid
}

private struct ParsedLine {
    let sourceLine: Int
    let address: MailboxAddress
    let label: String?
    let statement: Statement
}

private struct Parser {
    private var lines: [ParsedLine] = []
    private var diagnostics: [AssemblyDiagnostic] = []
    private var definitions: [String: MailboxAddress] = [:]
    private var reportedCapacity = false

    mutating func parse(_ line: Substring, number: Int) {
        let tokens = tokenize(line)
        guard let first = tokens.first else { return }

        var cursor = tokens.startIndex
        var label: String?
        if Mnemonic(first.text) == nil, Int(first.text) == nil {
            let name = first.text.last == ":" ? first.text.dropLast() : first.text
            if isValidLabel(name) {
                label = String(name)
            } else {
                report(.invalidLabel(String(first.text)), at: first, line: number)
            }
            cursor += 1
        }

        guard cursor < tokens.endIndex else {
            if let label {
                let kind: AssemblyDiagnostic.Kind = first.text.last == ":"
                    ? .missingMnemonic(label: label)
                    : .unknownMnemonic(label)
                report(kind, at: first, line: number)
            }
            emit(label: label, statement: .invalid, labelToken: first, line: number)
            return
        }

        let head = tokens[cursor]
        let operands = tokens[(cursor + 1)...]
        if let extra = operands.dropFirst().first {
            report(.unexpectedToken(String(extra.text)), at: extra, line: number)
        }

        let statement: Statement
        if let mnemonic = Mnemonic(head.text) {
            switch mnemonic {
            case .opcode(let opcode):
                statement = parseInstruction(opcode, head: head, operand: operands.first, line: number)
            case .data:
                statement = operands.first.map { parseData($0, line: number) } ?? .data(.none)
            }
        } else if let value = Int(head.text) {
            statement = parseData(head, value: value, line: number)
        } else {
            report(.unknownMnemonic(String(head.text)), at: head, line: number)
            statement = .invalid
        }

        emit(label: label, statement: statement, labelToken: first, line: number)
    }

    mutating func finish() throws(AssemblyError) -> Program {
        var memory = Memory()
        var programLines: [Program.Line] = []

        for parsed in lines {
            let kind: Program.Line.Kind
            switch parsed.statement {
            case .instruction(let opcode, let operand):
                kind = .instruction
                if let instruction = resolveInstruction(opcode, operand, line: parsed.sourceLine) {
                    memory[parsed.address] = instruction.word
                }
            case .data(let operand):
                kind = .data
                if let value = resolveData(operand, line: parsed.sourceLine) {
                    memory[parsed.address] = value
                }
            case .invalid:
                kind = .instruction
            }
            programLines.append(Program.Line(
                address: parsed.address,
                kind: kind,
                label: parsed.label,
                sourceLine: parsed.sourceLine
            ))
        }

        guard diagnostics.isEmpty else {
            let ordered = diagnostics.sorted { ($0.line, $0.column) < ($1.line, $1.column) }
            throw AssemblyError(diagnostics: ordered)
        }
        return Program(memory: memory, lines: programLines)
    }

    // MARK: Statements

    private mutating func parseInstruction(_ opcode: Opcode, head: Token, operand: Token?, line: Int) -> Statement {
        guard opcode.takesAddress else {
            if let operand {
                report(.unexpectedOperand(opcode), at: operand, line: line)
            }
            return .instruction(opcode, .none)
        }
        guard let operand else {
            report(.missingOperand(opcode), at: head, line: line)
            return .invalid
        }
        if let value = Int(operand.text) {
            guard MailboxAddress.range.contains(value) else {
                report(.addressOutOfRange(value), at: operand, line: line)
                return .invalid
            }
            return .instruction(opcode, .number(value))
        }
        guard isValidLabel(operand.text) else {
            report(.invalidOperand(String(operand.text)), at: operand, line: line)
            return .invalid
        }
        return .instruction(opcode, .symbol(String(operand.text), operand))
    }

    private mutating func parseData(_ operand: Token, line: Int) -> Statement {
        if let value = Int(operand.text) {
            return parseData(operand, value: value, line: line)
        }
        guard isValidLabel(operand.text) else {
            report(.invalidOperand(String(operand.text)), at: operand, line: line)
            return .invalid
        }
        return .data(.symbol(String(operand.text), operand))
    }

    private mutating func parseData(_ token: Token, value: Int, line: Int) -> Statement {
        guard Word.range.contains(value) else {
            report(.dataOutOfRange(value), at: token, line: line)
            return .invalid
        }
        return .data(.number(value))
    }

    private mutating func emit(label: String?, statement: Statement, labelToken: Token, line: Int) {
        guard lines.count < MailboxAddress.count else {
            if !reportedCapacity {
                report(.programTooLarge, at: labelToken, line: line)
                reportedCapacity = true
            }
            return
        }
        let address = MailboxAddress(wrapping: lines.count)
        if let label {
            let key = label.uppercased()
            if definitions[key] == nil {
                definitions[key] = address
            } else {
                report(.duplicateLabel(label), at: labelToken, line: line)
            }
        }
        lines.append(ParsedLine(sourceLine: line, address: address, label: label, statement: statement))
    }

    // MARK: Resolution

    private mutating func resolveInstruction(_ opcode: Opcode, _ operand: Operand, line: Int) -> Instruction? {
        switch operand {
        case .none:
            return Instruction(opcode: opcode, address: nil)
        case .number(let value):
            return Instruction(opcode: opcode, address: MailboxAddress(rawValue: value))
        case .symbol(let name, let token):
            guard let address = definitions[name.uppercased()] else {
                report(.undefinedLabel(name), at: token, line: line)
                return nil
            }
            return Instruction(opcode: opcode, address: address)
        }
    }

    private mutating func resolveData(_ operand: Operand, line: Int) -> Word? {
        switch operand {
        case .none:
            return .zero
        case .number(let value):
            return Word(rawValue: value)
        case .symbol(let name, let token):
            guard let address = definitions[name.uppercased()] else {
                report(.undefinedLabel(name), at: token, line: line)
                return nil
            }
            return Word(wrapping: address.rawValue)
        }
    }

    // MARK: Lexing

    private mutating func report(_ kind: AssemblyDiagnostic.Kind, at token: Token, line: Int) {
        diagnostics.append(AssemblyDiagnostic(line: line, column: token.column, kind: kind))
    }

    private func isValidLabel(_ text: Substring) -> Bool {
        guard let first = text.first, first.isLetter || first == "_" else { return false }
        guard text.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else { return false }
        return !Mnemonic.isReserved(text)
    }

    private func tokenize(_ line: Substring) -> [Token] {
        var tokens: [Token] = []
        var column = 0
        var tokenStart: (index: Substring.Index, column: Int)?
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]
            column += 1
            if isCommentStart(at: index, in: line) {
                break
            }
            if character.isWhitespace {
                if let start = tokenStart {
                    tokens.append(Token(text: line[start.index..<index], column: start.column))
                    tokenStart = nil
                }
            } else if tokenStart == nil {
                tokenStart = (index, column)
            }
            index = line.index(after: index)
        }

        if let start = tokenStart {
            tokens.append(Token(text: line[start.index..<index], column: start.column))
        }
        return tokens
    }

    private func isCommentStart(at index: Substring.Index, in line: Substring) -> Bool {
        switch line[index] {
        case ";", "#":
            return true
        case "/":
            let next = line.index(after: index)
            return next < line.endIndex && line[next] == "/"
        default:
            return false
        }
    }
}
