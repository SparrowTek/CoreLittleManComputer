public enum OperandKind: Sendable {
    case none
    case address
    case literal
}

public struct OpcodeMetadata: Sendable {
    public let mnemonic: String
    public let description: String
    public let operand: OperandKind
    public let baseWord: Int

    public init(mnemonic: String, description: String, operand: OperandKind, baseWord: Int) {
        self.mnemonic = mnemonic
        self.description = description
        self.operand = operand
        self.baseWord = baseWord
    }
}

public enum Opcode: CaseIterable, Sendable {
    case add
    case subtract
    case store
    case load
    case branch
    case branchIfZero
    case branchIfPositive
    case input
    case output
    case halt
    case data

    public var metadata: OpcodeMetadata {
        switch self {
        case .add:
            return OpcodeMetadata(mnemonic: "ADD", description: "Add mailbox value to accumulator", operand: .address, baseWord: 100)
        case .subtract:
            return OpcodeMetadata(mnemonic: "SUB", description: "Subtract mailbox value from accumulator", operand: .address, baseWord: 200)
        case .store:
            return OpcodeMetadata(mnemonic: "STA", description: "Store accumulator into mailbox", operand: .address, baseWord: 300)
        case .load:
            return OpcodeMetadata(mnemonic: "LDA", description: "Load mailbox into accumulator", operand: .address, baseWord: 500)
        case .branch:
            return OpcodeMetadata(mnemonic: "BRA", description: "Branch to mailbox", operand: .address, baseWord: 600)
        case .branchIfZero:
            return OpcodeMetadata(mnemonic: "BRZ", description: "Branch if accumulator is zero", operand: .address, baseWord: 700)
        case .branchIfPositive:
            return OpcodeMetadata(mnemonic: "BRP", description: "Branch if accumulator is positive", operand: .address, baseWord: 800)
        case .input:
            return OpcodeMetadata(mnemonic: "INP", description: "Read value into accumulator", operand: .none, baseWord: 901)
        case .output:
            return OpcodeMetadata(mnemonic: "OUT", description: "Write accumulator to output", operand: .none, baseWord: 902)
        case .halt:
            return OpcodeMetadata(mnemonic: "HLT", description: "Halt the program", operand: .none, baseWord: 0)
        case .data:
            return OpcodeMetadata(mnemonic: "DAT", description: "Reserve memory or define data", operand: .literal, baseWord: 0)
        }
    }
}
