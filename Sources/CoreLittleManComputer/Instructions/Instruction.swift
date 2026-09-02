/// A decoded instruction: an ``Opcode`` together with its mailbox, when it has one.
///
/// Because the address travels inside the case, an instruction can never be
/// missing an operand it needs or carry one it does not.
public enum Instruction: Hashable, Sendable, Codable {
    case add(MailboxAddress)
    case subtract(MailboxAddress)
    case store(MailboxAddress)
    case load(MailboxAddress)
    case branchAlways(MailboxAddress)
    case branchIfZero(MailboxAddress)
    case branchIfPositive(MailboxAddress)
    case input
    case output
    case halt

    /// Decodes `word` the way the Little Man reads it, or returns `nil` when
    /// the word is not an instruction.
    ///
    /// The hundreds digit selects the operation and the low two digits name
    /// the mailbox. Any word from `000` to `099` halts; only `901` and `902`
    /// are valid in the nine hundreds; and `4xx` is not an instruction at all.
    public init?(word: Word) {
        let address = word.addressField
        switch word.hundredsDigit {
        case 0: self = .halt
        case 1: self = .add(address)
        case 2: self = .subtract(address)
        case 3: self = .store(address)
        case 5: self = .load(address)
        case 6: self = .branchAlways(address)
        case 7: self = .branchIfZero(address)
        case 8: self = .branchIfPositive(address)
        case 9:
            switch word.rawValue {
            case 901: self = .input
            case 902: self = .output
            default: return nil
            }
        default:
            return nil
        }
    }

    /// Pairs an opcode with an address, or returns `nil` when the opcode
    /// needs an address and none is given, or takes none and one is given.
    public init?(opcode: Opcode, address: MailboxAddress?) {
        switch (opcode, address) {
        case (.add, let address?): self = .add(address)
        case (.subtract, let address?): self = .subtract(address)
        case (.store, let address?): self = .store(address)
        case (.load, let address?): self = .load(address)
        case (.branchAlways, let address?): self = .branchAlways(address)
        case (.branchIfZero, let address?): self = .branchIfZero(address)
        case (.branchIfPositive, let address?): self = .branchIfPositive(address)
        case (.input, nil): self = .input
        case (.output, nil): self = .output
        case (.halt, nil): self = .halt
        default: return nil
        }
    }

    /// The operation this instruction performs.
    public var opcode: Opcode {
        switch self {
        case .add: .add
        case .subtract: .subtract
        case .store: .store
        case .load: .load
        case .branchAlways: .branchAlways
        case .branchIfZero: .branchIfZero
        case .branchIfPositive: .branchIfPositive
        case .input: .input
        case .output: .output
        case .halt: .halt
        }
    }

    /// The mailbox the instruction refers to, or `nil` for `INP`, `OUT` and `HLT`.
    public var address: MailboxAddress? {
        switch self {
        case .add(let address), .subtract(let address), .store(let address), .load(let address),
             .branchAlways(let address), .branchIfZero(let address), .branchIfPositive(let address):
            address
        case .input, .output, .halt:
            nil
        }
    }

    /// `true` for `BRA`, `BRZ` and `BRP`.
    public var isBranch: Bool {
        switch self {
        case .branchAlways, .branchIfZero, .branchIfPositive: true
        default: false
        }
    }

    /// The canonical machine word for this instruction.
    ///
    /// Decoding this word always yields the same instruction. The reverse is
    /// not guaranteed: `042` decodes to `HLT`, whose canonical word is `000`.
    public var word: Word {
        // The largest sum is 899 (BRP 99), so wrapping never occurs.
        Word(wrapping: opcode.baseWord.rawValue + (address?.rawValue ?? 0))
    }
}

extension Instruction: CustomStringConvertible {
    /// The instruction in assembly form, such as `"ADD 07"` or `"HLT"`.
    public var description: String {
        if let address {
            "\(opcode.mnemonic) \(address)"
        } else {
            opcode.mnemonic
        }
    }
}
