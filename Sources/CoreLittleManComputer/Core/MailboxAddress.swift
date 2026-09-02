/// The number of one of the 100 mailboxes, `00` through `99`.
///
/// Addresses appear in three places: as the low two digits of an instruction
/// word, as the value of the program counter, and as the key for reading or
/// writing ``Memory``.
public struct MailboxAddress: RawRepresentable, Hashable, Comparable, Sendable, Codable {
    /// The valid mailbox numbers.
    public static let range: ClosedRange<Int> = 0...99

    /// The number of mailboxes in the machine.
    public static let count = 100

    /// Mailbox `00`, where execution begins.
    public static let zero: MailboxAddress = 0

    /// The mailbox number, always within ``range``.
    public let rawValue: Int

    /// Creates an address from a value in ``range``, or returns `nil`.
    public init?(rawValue: Int) {
        guard Self.range.contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    /// Creates an address from the low two decimal digits of `value`.
    public init(wrapping value: Int) {
        let remainder = value % Self.count
        rawValue = remainder < 0 ? remainder + Self.count : remainder
    }

    /// The next mailbox, wrapping from `99` back to `00` the way the
    /// two-digit program counter does.
    public var successor: MailboxAddress {
        MailboxAddress(wrapping: rawValue + 1)
    }

    public static func < (lhs: MailboxAddress, rhs: MailboxAddress) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension MailboxAddress: CaseIterable {
    /// Every mailbox address in ascending order.
    public static let allCases: [MailboxAddress] = range.map(MailboxAddress.init(wrapping:))
}

extension MailboxAddress: ExpressibleByIntegerLiteral {
    /// Creates an address from a literal such as `42`.
    ///
    /// Literals are checked at run time; a literal outside ``range`` is a
    /// programming error and traps. Use ``init(rawValue:)`` for values that
    /// come from data.
    public init(integerLiteral value: Int) {
        precondition(Self.range.contains(value), "MailboxAddress literal \(value) is outside \(Self.range)")
        rawValue = value
    }
}

extension MailboxAddress: CustomStringConvertible, LosslessStringConvertible {
    /// The address as two zero-padded digits, such as `"07"`.
    public var description: String {
        rawValue < 10 ? "0\(rawValue)" : String(rawValue)
    }

    /// Parses a decimal string such as `"7"` or `"07"`.
    public init?(_ description: String) {
        guard let value = Int(description) else { return nil }
        self.init(rawValue: value)
    }
}
