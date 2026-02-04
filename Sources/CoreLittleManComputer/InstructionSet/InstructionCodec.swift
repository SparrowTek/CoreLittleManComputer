public struct InstructionWord: Equatable, Sendable {
    public enum Decoded: Equatable, Sendable {
        case instruction(Instruction)
        case data(Word)
    }

    public let word: Word

    public init(_ word: Word) {
        self.word = word
    }

    public init(rawValue: Int) {
        self.word = Word(rawValue)
    }

    public func decode() throws -> Decoded {
        let value = word.rawValue
        let hundreds = word.highDigit

        switch hundreds {
        case 1: return .instruction(try makeInstruction(.add, operandValue: word.lowValue))
        case 2: return .instruction(try makeInstruction(.subtract, operandValue: word.lowValue))
        case 3: return .instruction(try makeInstruction(.store, operandValue: word.lowValue))
        case 5: return .instruction(try makeInstruction(.load, operandValue: word.lowValue))
        case 6: return .instruction(try makeInstruction(.branch, operandValue: word.lowValue))
        case 7: return .instruction(try makeInstruction(.branchIfZero, operandValue: word.lowValue))
        case 8: return .instruction(try makeInstruction(.branchIfPositive, operandValue: word.lowValue))
        case 9:
            switch value {
            case 901:
                return .instruction(try Instruction(opcode: .input))
            case 902:
                return .instruction(try Instruction(opcode: .output))
            default:
                return .data(word)
            }
        case 0:
            if value == 0 {
                return .instruction(try Instruction(opcode: .halt))
            } else {
                return .data(word)
            }
        default:
            return .data(word)
        }
    }

    public static func encode(_ instruction: Instruction, numericPolicy: NumericPolicy = .trapOnOverflow) throws -> Word {
        switch instruction.opcode {
        case .add, .subtract, .store, .load, .branch, .branchIfZero, .branchIfPositive:
            guard case let .address(address) = instruction.operand else {
                throw InstructionError.encodingAddressRequired(instruction.opcode)
            }
            return Word(instruction.opcode.metadata.baseWord + address.rawValue)
        case .input, .output:
            return Word(instruction.opcode.metadata.baseWord)
        case .halt:
            return Word.zero
        case .data:
            guard case let .literal(value) = instruction.operand else {
                throw InstructionError.encodingLiteralRequired(instruction.opcode)
            }
            return try numericPolicy.word(fromSigned: value)
        }
    }

    private func makeInstruction(_ opcode: Opcode, operandValue: Int) throws -> Instruction {
        let address = MailboxAddress(operandValue)
        return try Instruction(opcode: opcode, operand: .address(address))
    }
}
