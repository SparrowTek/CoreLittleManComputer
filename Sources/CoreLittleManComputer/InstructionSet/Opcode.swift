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

    private static let table: [Opcode: OpcodeMetadata] = [
        .add: OpcodeMetadata(mnemonic: "ADD", description: "Add mailbox value to accumulator", operand: .address, baseWord: 100),
        .subtract: OpcodeMetadata(mnemonic: "SUB", description: "Subtract mailbox value from accumulator", operand: .address, baseWord: 200),
        .store: OpcodeMetadata(mnemonic: "STA", description: "Store accumulator into mailbox", operand: .address, baseWord: 300),
        .load: OpcodeMetadata(mnemonic: "LDA", description: "Load mailbox into accumulator", operand: .address, baseWord: 500),
        .branch: OpcodeMetadata(mnemonic: "BRA", description: "Branch to mailbox", operand: .address, baseWord: 600),
        .branchIfZero: OpcodeMetadata(mnemonic: "BRZ", description: "Branch if accumulator is zero", operand: .address, baseWord: 700),
        .branchIfPositive: OpcodeMetadata(mnemonic: "BRP", description: "Branch if accumulator is positive", operand: .address, baseWord: 800),
        .input: OpcodeMetadata(mnemonic: "INP", description: "Read value into accumulator", operand: .none, baseWord: 901),
        .output: OpcodeMetadata(mnemonic: "OUT", description: "Write accumulator to output", operand: .none, baseWord: 902),
        .halt: OpcodeMetadata(mnemonic: "HLT", description: "Halt the program", operand: .none, baseWord: 0),
        .data: OpcodeMetadata(mnemonic: "DAT", description: "Reserve memory or define data", operand: .literal, baseWord: 0),
    ]

    public var metadata: OpcodeMetadata {
        Self.table[self]!
    }
}
