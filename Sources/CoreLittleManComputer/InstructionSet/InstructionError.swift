public enum InstructionError: Error, Sendable, Equatable, CustomStringConvertible {
    case operandRequired(Opcode)
    case unexpectedOperand(Opcode)
    case literalOutOfRange(Int)
    case decodingFailed(Word)
    case encodingAddressRequired(Opcode)
    case encodingLiteralRequired(Opcode)

    public var description: String {
        switch self {
        case .operandRequired(let opcode):
            return "\(opcode.metadata.mnemonic) requires an operand"
        case .unexpectedOperand(let opcode):
            return "\(opcode.metadata.mnemonic) does not take an operand"
        case .literalOutOfRange(let value):
            return "Literal \(value) is outside the valid range \(LMCConstants.signedWordRange)"
        case .decodingFailed(let word):
            return "Cannot decode word \(word) as an instruction"
        case .encodingAddressRequired(let opcode):
            return "\(opcode.metadata.mnemonic) requires an address operand for encoding"
        case .encodingLiteralRequired(let opcode):
            return "\(opcode.metadata.mnemonic) requires a literal operand for encoding"
        }
    }
}
