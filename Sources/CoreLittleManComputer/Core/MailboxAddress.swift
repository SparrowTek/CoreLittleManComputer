public struct MailboxAddress: Equatable, Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public static let validRange: Range<Int> = 0..<LMCConstants.mailboxCount
    public static let zero = MailboxAddress(0)

    public let rawValue: Int

    public var description: String { String(rawValue) }

    public init(_ rawValue: Int) {
        precondition(MailboxAddress.validRange.contains(rawValue), "Mailbox address must be 0..<100")
        self.rawValue = rawValue
    }

    public init?(exactly rawValue: Int) {
        guard MailboxAddress.validRange.contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public func advanced(by offset: Int) -> MailboxAddress {
        let newValue = rawValue + offset
        precondition(MailboxAddress.validRange.contains(newValue), "Mailbox address advanced out of range")
        return MailboxAddress(newValue)
    }

    public static func < (lhs: MailboxAddress, rhs: MailboxAddress) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int.self)
        guard MailboxAddress.validRange.contains(value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Mailbox address must be 0..<100")
        }
        self.rawValue = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
