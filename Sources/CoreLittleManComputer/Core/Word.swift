/// A three-digit decimal value, `000` through `999`.
///
/// The word is the fundamental unit of the Little Man Computer. Every mailbox
/// holds exactly one word, every card in the in-basket carries one word, and
/// every instruction is encoded as one word whose hundreds digit is the opcode
/// and whose remaining two digits form the address field.
///
/// Words are unsigned. The accumulator is the only signed register in the
/// machine; see ``SignedWord``.
public struct Word: RawRepresentable, Hashable, Comparable, Sendable, Codable {
    /// The values a word can represent.
    public static let range: ClosedRange<Int> = 0...999

    /// The number of distinct values a word can hold.
    public static let modulus = 1_000

    /// The word `000`.
    public static let zero: Word = 0

    /// The value of the word, always within ``range``.
    public let rawValue: Int

    /// Creates a word from a value in ``range``, or returns `nil`.
    public init?(rawValue: Int) {
        guard Self.range.contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    /// Creates a word from the low three decimal digits of `value`.
    ///
    /// Negative values wrap the way a three-digit counter would, which is the
    /// ten's-complement representation: `-1` becomes `999`.
    public init(wrapping value: Int) {
        let remainder = value % Self.modulus
        rawValue = remainder < 0 ? remainder + Self.modulus : remainder
    }

    /// The hundreds digit, which an instruction uses as its opcode.
    public var hundredsDigit: Int {
        rawValue / 100
    }

    /// The low two digits, which an instruction uses as its address.
    public var addressField: MailboxAddress {
        MailboxAddress(wrapping: rawValue % 100)
    }

    public static func < (lhs: Word, rhs: Word) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension Word: ExpressibleByIntegerLiteral {
    /// Creates a word from a literal such as `123`.
    ///
    /// Literals are checked at run time; a literal outside ``range`` is a
    /// programming error and traps. Use ``init(rawValue:)`` for values that
    /// come from data.
    public init(integerLiteral value: Int) {
        precondition(Self.range.contains(value), "Word literal \(value) is outside \(Self.range)")
        rawValue = value
    }
}

extension Word: CustomStringConvertible, LosslessStringConvertible {
    /// The word as three zero-padded digits, such as `"042"`.
    public var description: String {
        let digits = String(rawValue)
        return String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// Parses a decimal string such as `"42"` or `"042"`.
    public init?(_ description: String) {
        guard let value = Int(description) else { return nil }
        self.init(rawValue: value)
    }
}
