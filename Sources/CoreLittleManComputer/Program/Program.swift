public struct Program: Sendable {
    public let words: [Word]
    public let labels: [String: MailboxAddress]

    public init(words: [Word], labels: [String: MailboxAddress] = [:]) {
        precondition(words.count <= LMCConstants.mailboxCount, "Program cannot exceed mailbox capacity")
        self.words = words
        self.labels = labels
    }
}
