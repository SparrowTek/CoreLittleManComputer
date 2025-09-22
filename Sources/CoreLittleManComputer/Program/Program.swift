public struct SourceLocation: Equatable, Sendable {
    public let line: Int
    public let column: Int

    public init(line: Int, column: Int) {
        precondition(line >= 1 && column >= 1, "Source locations are 1-based indices")
        self.line = line
        self.column = column
    }
}

public struct Program: Sendable {
    public static let capacity = LMCConstants.mailboxCount

    private let memory: [Word]
    public let usedRange: Range<Int>
    public let labels: [String: MailboxAddress]
    public let sourceMap: [MailboxAddress: SourceLocation]

    public init(words: [Word],
                labels: [String: MailboxAddress] = [:],
                sourceMap: [MailboxAddress: SourceLocation] = [:]) {
        precondition(words.count <= Self.capacity, "Program cannot exceed mailbox capacity")
        var storage = Array(repeating: Word.zero, count: Self.capacity)
        for (offset, word) in words.enumerated() {
            storage[offset] = word
        }
        self.memory = storage
        self.usedRange = 0..<words.count
        self.labels = labels
        self.sourceMap = sourceMap
    }

    public func word(at address: MailboxAddress) -> Word {
        memory[address.rawValue]
    }

    public func decoded(at address: MailboxAddress) throws -> InstructionWord.Decoded {
        try InstructionWord(word(at: address)).decode()
    }

    public func label(named name: String) -> MailboxAddress? {
        labels[name]
    }

    public func sourceLocation(for address: MailboxAddress) -> SourceLocation? {
        sourceMap[address]
    }
}
