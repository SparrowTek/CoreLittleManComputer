/// A word the assembler recognises in the instruction position: an opcode
/// mnemonic, one of its aliases, or the `DAT` directive.
enum Mnemonic: Hashable, Sendable {
    case opcode(Opcode)
    case data

    private static let table: [String: Mnemonic] = {
        var table: [String: Mnemonic] = ["DAT": .data]
        for opcode in Opcode.allCases {
            table[opcode.mnemonic] = .opcode(opcode)
            for alias in opcode.aliases {
                table[alias] = .opcode(opcode)
            }
        }
        return table
    }()

    /// Looks up `token` without regard to case.
    init?(_ token: some StringProtocol) {
        guard let mnemonic = Self.table[token.uppercased()] else { return nil }
        self = mnemonic
    }

    /// `true` when `text` would be read as a mnemonic and so cannot be a label.
    static func isReserved(_ text: some StringProtocol) -> Bool {
        table[text.uppercased()] != nil
    }
}
