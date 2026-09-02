/// A three-digit magnitude with a sign, `-999` through `999`.
///
/// This is the value held by the accumulator and the value that `OUT` places
/// in the out-basket. Mailboxes cannot hold a sign, so storing a negative
/// accumulator with `STA` keeps only the ten's-complement word; see
/// ``Machine`` for the exact rules.
public struct SignedWord: RawRepresentable, Hashable, Comparable, Sendable, Codable {
    /// The values a signed word can represent.
    public static let range: ClosedRange<Int> = -999...999

    /// The value `0`.
    public static let zero: SignedWord = 0

    /// The value, always within ``range``.
    public let rawValue: Int

    /// Creates a signed word from a value in ``range``, or returns `nil`.
    public init?(rawValue: Int) {
        guard Self.range.contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    /// Creates a signed word with the same value as `word`. Never loses information.
    public init(_ word: Word) {
        rawValue = word.rawValue
    }

    /// Creates a signed word that keeps the sign of `value` and the low three
    /// digits of its magnitude, the way a three-digit display with a sign
    /// indicator would show an oversized result.
    public init(wrapping value: Int) {
        let magnitude = Int(value.magnitude % UInt(Word.modulus))
        rawValue = value < 0 ? -magnitude : magnitude
    }

    /// `true` when the value is below zero.
    public var isNegative: Bool {
        rawValue < 0
    }

    /// `true` when the value is exactly zero.
    public var isZero: Bool {
        rawValue == 0
    }

    /// The word a mailbox receives when this value is stored with `STA`.
    ///
    /// Non-negative values are stored as they are. Negative values are stored
    /// in ten's complement, so `-1` becomes `999`.
    public var storedWord: Word {
        Word(wrapping: rawValue)
    }

    public static func < (lhs: SignedWord, rhs: SignedWord) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension SignedWord: ExpressibleByIntegerLiteral {
    /// Creates a signed word from a literal such as `-3`.
    ///
    /// Literals are checked at run time; a literal outside ``range`` is a
    /// programming error and traps. Use ``init(rawValue:)`` for values that
    /// come from data.
    public init(integerLiteral value: Int) {
        precondition(Self.range.contains(value), "SignedWord literal \(value) is outside \(Self.range)")
        rawValue = value
    }
}

extension SignedWord: CustomStringConvertible, LosslessStringConvertible {
    /// The value as a plain decimal string, such as `"-3"` or `"42"`.
    public var description: String {
        String(rawValue)
    }

    /// Parses a decimal string such as `"-3"` or `"042"`.
    public init?(_ description: String) {
        guard let value = Int(description) else { return nil }
        self.init(rawValue: value)
    }
}
