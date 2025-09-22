public enum InstructionError: Error, Sendable, Equatable {
    case operandRequired(Opcode)
    case unexpectedOperand(Opcode)
    case literalOutOfRange(Int)
}
