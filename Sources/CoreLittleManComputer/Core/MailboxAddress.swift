public struct MailboxAddress: Equatable, Hashable, Comparable, Sendable {
    public static let validRange: Range<Int> = 0..<LMCConstants.mailboxCount

    public let rawValue: Int

    public init(_ rawValue: Int) {
        precondition(MailboxAddress.validRange.contains(rawValue), "Mailbox address must be 0..<100")
        self.rawValue = rawValue
    }

    public static func < (lhs: MailboxAddress, rhs: MailboxAddress) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
