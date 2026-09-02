/// One of the ten operations the Little Man can perform.
///
/// The raw value is the canonical assembly mnemonic. `DAT` is not an opcode:
/// it is an assembler directive that reserves a mailbox, and it never reaches
/// the machine.
public enum Opcode: String, CaseIterable, Hashable, Sendable, Codable {
    /// `1xx` — add the word in mailbox `xx` to the accumulator.
    case add = "ADD"
    /// `2xx` — subtract the word in mailbox `xx` from the accumulator.
    case subtract = "SUB"
    /// `3xx` — store the accumulator in mailbox `xx`.
    case store = "STA"
    /// `5xx` — load the word in mailbox `xx` into the accumulator.
    case load = "LDA"
    /// `6xx` — continue execution at mailbox `xx`.
    case branchAlways = "BRA"
    /// `7xx` — continue at mailbox `xx` if the accumulator is zero.
    case branchIfZero = "BRZ"
    /// `8xx` — continue at mailbox `xx` if the accumulator is zero or positive.
    case branchIfPositive = "BRP"
    /// `901` — take the next card from the in-basket into the accumulator.
    case input = "INP"
    /// `902` — copy the accumulator to the out-basket.
    case output = "OUT"
    /// `000` — stop; the Little Man takes a coffee break.
    case halt = "HLT"

    /// The canonical assembly mnemonic, such as `"ADD"`.
    public var mnemonic: String {
        rawValue
    }

    /// Alternate mnemonics the assembler also accepts.
    public var aliases: [String] {
        switch self {
        case .store: ["STO"]
        case .halt: ["COB"]
        default: []
        }
    }

    /// `true` when the instruction's low two digits name a mailbox.
    public var takesAddress: Bool {
        switch self {
        case .add, .subtract, .store, .load, .branchAlways, .branchIfZero, .branchIfPositive: true
        case .input, .output, .halt: false
        }
    }

    /// The word that encodes this opcode with an address field of `00`.
    ///
    /// For addressed instructions the mailbox number is added to this word.
    public var baseWord: Word {
        switch self {
        case .add: 100
        case .subtract: 200
        case .store: 300
        case .load: 500
        case .branchAlways: 600
        case .branchIfZero: 700
        case .branchIfPositive: 800
        case .input: 901
        case .output: 902
        case .halt: 000
        }
    }

    /// A one-sentence description suitable for help screens.
    public var summary: String {
        switch self {
        case .add: "Add the value in the mailbox to the accumulator."
        case .subtract: "Subtract the value in the mailbox from the accumulator."
        case .store: "Store the accumulator in the mailbox."
        case .load: "Load the value in the mailbox into the accumulator."
        case .branchAlways: "Continue execution at the mailbox."
        case .branchIfZero: "Continue at the mailbox if the accumulator is zero."
        case .branchIfPositive: "Continue at the mailbox if the accumulator is zero or positive."
        case .input: "Take the next value from the in-basket into the accumulator."
        case .output: "Copy the accumulator to the out-basket."
        case .halt: "Stop the program."
        }
    }
}
