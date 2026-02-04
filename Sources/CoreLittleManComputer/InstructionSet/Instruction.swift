public enum Operand: Equatable, Sendable {
    case none
    case address(MailboxAddress)
    case literal(Int)
}

public struct Instruction: Equatable, Sendable, CustomStringConvertible {
    public let opcode: Opcode
    public let operand: Operand

    public var description: String {
        switch operand {
        case .none:
            return opcode.metadata.mnemonic
        case .address(let address):
            return "\(opcode.metadata.mnemonic) \(address.rawValue)"
        case .literal(let value):
            return "\(opcode.metadata.mnemonic) \(value)"
        }
    }

    public init(opcode: Opcode, operand: Operand = .none) throws {
        try Instruction.validate(opcode: opcode, operand: operand)
        self.opcode = opcode
        self.operand = operand
    }

    private static func validate(opcode: Opcode, operand: Operand) throws {
        switch opcode.metadata.operand {
        case .none:
            guard operand == .none else { throw InstructionError.unexpectedOperand(opcode) }
        case .address:
            guard case .address = operand else { throw InstructionError.operandRequired(opcode) }
        case .literal:
            guard case let .literal(value) = operand else { throw InstructionError.operandRequired(opcode) }
            guard LMCConstants.signedWordRange.contains(value) else {
                throw InstructionError.literalOutOfRange(value)
            }
        }
    }
}
