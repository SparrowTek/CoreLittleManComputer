public enum AssemblerError: Error, Sendable, Equatable {
    case invalidOpcode(line: Int, mnemonic: String)
    case operandExpected(line: Int, opcode: Opcode)
    case operandUnexpected(line: Int, opcode: Opcode)
    case addressOutOfRange(line: Int, value: Int)
    case literalOutOfRange(line: Int, value: Int)
    case duplicateLabel(line: Int, label: String)
    case unresolvedSymbol(line: Int, symbol: String)
    case trailingTokens(line: Int)
    case programTooLarge(line: Int)
}

public struct Assembler: Sendable {
    public let numericPolicy: NumericPolicy

    public init(numericPolicy: NumericPolicy = .trapOnOverflow) {
        self.numericPolicy = numericPolicy
    }

    public func assemble(_ source: String) throws -> Program {
        var instructions: [ParsedInstruction] = []
        var labels: [String: (address: MailboxAddress, line: Int)] = [:]
        var sourceMap: [MailboxAddress: SourceLocation] = [:]

        var currentAddress = 0
        let lines = source.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })

        for (index, rawLine) in lines.enumerated() {
            let lineNumber = index + 1
            let strippedLine = stripComment(from: rawLine)
            let trimmedLine = trimmed(strippedLine)

            guard !trimmedLine.isEmpty else { continue }

            let tokens = tokenize(trimmedLine)
            guard !tokens.isEmpty else { continue }

            var tokenIndex = 0
            var label: String?

            if opcode(from: tokens[0]) == nil {
                label = normalizeSymbol(tokens[0])
                tokenIndex += 1
            }

            guard tokenIndex < tokens.count else {
                throw AssemblerError.invalidOpcode(line: lineNumber, mnemonic: label ?? "")
            }

            let opcodeToken = tokens[tokenIndex]
            guard let opcode = opcode(from: opcodeToken) else {
                throw AssemblerError.invalidOpcode(line: lineNumber, mnemonic: String(opcodeToken))
            }

            let operandCount = tokens.count - (tokenIndex + 1)
            if operandCount > 1 {
                throw AssemblerError.trailingTokens(line: lineNumber)
            }

            let operandToken = operandCount == 1 ? String(tokens.last!) : nil
            let operand = try parseOperand(opcode: opcode, operandToken: operandToken, line: lineNumber)

            guard currentAddress < Program.capacity else {
                throw AssemblerError.programTooLarge(line: lineNumber)
            }

            let mailbox = MailboxAddress(currentAddress)

            if let label {
                if labels[label] != nil {
                    throw AssemblerError.duplicateLabel(line: lineNumber, label: label)
                }
                labels[label] = (mailbox, lineNumber)
            }

            instructions.append(ParsedInstruction(line: lineNumber,
                                                  address: mailbox,
                                                  opcode: opcode,
                                                  operand: operand))
            sourceMap[mailbox] = SourceLocation(line: lineNumber, column: leadingColumn(in: rawLine))

            currentAddress += 1
        }

        let resolvedLabels: [String: MailboxAddress] = Dictionary(uniqueKeysWithValues: labels.map { ($0.key, $0.value.address) })

        let words: [Word] = try instructions.map { parsed in
            try encode(parsed, labels: resolvedLabels)
        }

        return Program(words: words, labels: resolvedLabels, sourceMap: sourceMap)
    }

    public func disassemble(_ program: Program) -> String {
        var components: [String] = []
        var reverseLabels: [Int: [String]] = [:]

        for (label, address) in program.labels {
            reverseLabels[address.rawValue, default: []].append(label)
        }

        let usedRange = program.usedRange
        for index in usedRange.lowerBound..<usedRange.upperBound {
            let address = MailboxAddress(index)
            let word = program.word(at: address)
            let decoded = try? InstructionWord(word).decode()
            let prefixLabels = reverseLabels[index]?.sorted().joined(separator: " ")

            switch decoded {
            case .instruction(let instruction):
                components.append(renderInstruction(instruction,
                                                    labels: prefixLabels,
                                                    symbolForAddress: { address in
                    reverseLabels[address.rawValue]?.sorted().first
                }))
            case .data(let data):
                components.append(renderData(data, labels: prefixLabels))
            case .none:
                components.append(renderData(word, labels: prefixLabels))
            }
        }

        return components.joined(separator: "\n")
    }

    private func encode(_ instruction: ParsedInstruction, labels: [String: MailboxAddress]) throws -> Word {
        switch instruction.opcode {
        case .data:
            return try encodeData(instruction, labels: labels)
        default:
            return try encodeInstruction(instruction, labels: labels)
        }
    }

    private func encodeInstruction(_ instruction: ParsedInstruction, labels: [String: MailboxAddress]) throws -> Word {
        let operand: Operand
        switch instruction.operand {
        case .none:
            operand = .none
        case .mailboxLiteral(let value):
            operand = .address(MailboxAddress(value))
        case .mailboxSymbol(let symbol):
            guard let address = labels[symbol] else {
                throw AssemblerError.unresolvedSymbol(line: instruction.line, symbol: symbol)
            }
            operand = .address(address)
        case .literalValue:
            throw AssemblerError.operandUnexpected(line: instruction.line, opcode: instruction.opcode)
        case .literalSymbol:
            throw AssemblerError.operandUnexpected(line: instruction.line, opcode: instruction.opcode)
        }

        let instruction = try Instruction(opcode: instruction.opcode, operand: operand)
        return try InstructionWord.encode(instruction)
    }

    private func encodeData(_ instruction: ParsedInstruction, labels: [String: MailboxAddress]) throws -> Word {
        switch instruction.operand {
        case .literalValue(let value):
            return try encodeLiteral(value, line: instruction.line)
        case .literalSymbol(let symbol):
            guard let address = labels[symbol] else {
                throw AssemblerError.unresolvedSymbol(line: instruction.line, symbol: symbol)
            }
            return Word(address.rawValue)
        case .mailboxLiteral(let value):
            return Word(value)
        case .mailboxSymbol(let symbol):
            guard let address = labels[symbol] else {
                throw AssemblerError.unresolvedSymbol(line: instruction.line, symbol: symbol)
            }
            return Word(address.rawValue)
        case .none:
            return Word.zero
        }
    }

    private func encodeLiteral(_ value: Int, line: Int) throws -> Word {
        if value >= 0 {
            guard LMCConstants.wordRange.contains(value) else {
                throw AssemblerError.literalOutOfRange(line: line, value: value)
            }
            return Word(value)
        }

        do {
            return try numericPolicy.word(fromSigned: value)
        } catch {
            throw AssemblerError.literalOutOfRange(line: line, value: value)
        }
    }

    private func parseOperand(opcode: Opcode, operandToken: String?, line: Int) throws -> OperandDescriptor {
        switch opcode.metadata.operand {
        case .none:
            if operandToken != nil {
                throw AssemblerError.operandUnexpected(line: line, opcode: opcode)
            }
            return .none
        case .address:
            guard let operandToken else {
                throw AssemblerError.operandExpected(line: line, opcode: opcode)
            }
            if let value = Int(operandToken) {
                guard MailboxAddress.validRange.contains(value) else {
                    throw AssemblerError.addressOutOfRange(line: line, value: value)
                }
                return .mailboxLiteral(value)
            }
            return .mailboxSymbol(normalizeSymbol(operandToken))
        case .literal:
            guard let operandToken else {
                return .literalValue(0)
            }
            if let value = Int(operandToken) {
                if value >= 0 {
                    guard LMCConstants.wordRange.contains(value) else {
                        throw AssemblerError.literalOutOfRange(line: line, value: value)
                    }
                } else if value < LMCConstants.signedWordRange.lowerBound {
                    throw AssemblerError.literalOutOfRange(line: line, value: value)
                }
                return .literalValue(value)
            }
            return .literalSymbol(normalizeSymbol(operandToken))
        }
    }

    private func opcode(from token: Substring) -> Opcode? {
        let uppercased = token.uppercased()
        return Opcode.allCases.first { $0.metadata.mnemonic == uppercased }
    }

    private func tokenize(_ line: String) -> [Substring] {
        line.split(whereSeparator: { $0.isWhitespace })
    }

    private func stripComment(from line: Substring) -> String {
        let markers = ["//", "#", ";"]
        var result = String(line)
        for marker in markers {
            if let range = result.range(of: marker) {
                result = String(result[..<range.lowerBound])
            }
        }
        return result
    }

    private func trimmed(_ line: String) -> String {
        guard let firstIndex = line.firstIndex(where: { !$0.isWhitespace }) else { return "" }
        guard let lastIndex = line.lastIndex(where: { !$0.isWhitespace }) else { return "" }
        return String(line[firstIndex...lastIndex])
    }

    private func normalizeSymbol(_ symbol: String) -> String {
        symbol.uppercased()
    }

    private func normalizeSymbol(_ token: Substring) -> String {
        normalizeSymbol(String(token))
    }

    private func leadingColumn(in line: Substring) -> Int {
        var column = 1
        for character in line {
            if character.isWhitespace {
                column += 1
            } else {
                break
            }
        }
        return column
    }
}

private struct ParsedInstruction: Sendable {
    let line: Int
    let address: MailboxAddress
    let opcode: Opcode
    let operand: OperandDescriptor
}

private enum OperandDescriptor: Sendable {
    case none
    case mailboxLiteral(Int)
    case mailboxSymbol(String)
    case literalValue(Int)
    case literalSymbol(String)
}

private func renderInstruction(
    _ instruction: Instruction,
    labels: String?,
    symbolForAddress: (MailboxAddress) -> String?
) -> String {
    let mnemonic = instruction.opcode.metadata.mnemonic
    var parts: [String] = []
    if let labels, !labels.isEmpty {
        parts.append(labels)
    }
    parts.append(mnemonic)

    switch instruction.operand {
    case .none:
        break
    case .address(let address):
        if let symbol = symbolForAddress(address) {
            parts.append(symbol)
        } else {
            parts.append(String(address.rawValue))
        }
    case .literal(let value):
        parts.append(String(value))
    }

    return parts.joined(separator: " ")
}

private func renderData(_ word: Word, labels: String?) -> String {
    var parts: [String] = []
    if let labels, !labels.isEmpty {
        parts.append(labels)
    }
    parts.append("DAT")
    parts.append(String(word.signedValue))
    return parts.joined(separator: " ")
}
