public enum Operand: Equatable, Sendable {
    case none
    case address(MailboxAddress)
    case literal(Int)
}

public struct Instruction: Equatable, Sendable {
    public let opcode: Opcode
    public let operand: Operand

    public init(opcode: Opcode, operand: Operand = .none) {
        self.opcode = opcode
        self.operand = operand
    }
}
