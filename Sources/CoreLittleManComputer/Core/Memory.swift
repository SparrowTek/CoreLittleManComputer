/// The 100 mailboxes of the Little Man Computer.
///
/// Memory always contains exactly ``MailboxAddress/count`` words, so reads and
/// writes by ``MailboxAddress`` can never fail. A freshly created memory holds
/// `000` in every mailbox.
public struct Memory: Hashable, Sendable {
    /// Memory with `000` in every mailbox.
    public static let empty = Memory()

    /// The contents of every mailbox, in address order.
    public private(set) var words: [Word]

    /// Creates memory with `000` in every mailbox.
    public init() {
        words = Array(repeating: .zero, count: MailboxAddress.count)
    }

    /// Creates memory whose first mailboxes hold `words`, padded with `000`.
    ///
    /// Returns `nil` when more than ``MailboxAddress/count`` words are supplied.
    public init?(words: [Word]) {
        guard words.count <= MailboxAddress.count else { return nil }
        self.words = words + Array(repeating: .zero, count: MailboxAddress.count - words.count)
    }

    /// The word held by the mailbox at `address`.
    public subscript(address: MailboxAddress) -> Word {
        get { words[address.rawValue] }
        set { words[address.rawValue] = newValue }
    }

    /// The highest address holding a non-zero word, or `nil` when memory is blank.
    public var lastOccupiedAddress: MailboxAddress? {
        words.lastIndex { $0 != .zero }.map(MailboxAddress.init(wrapping:))
    }
}

extension Memory: Codable {
    /// Encodes memory as an array of 100 integers.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(words)
    }

    /// Decodes memory from an array of exactly 100 integers in `0...999`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let words = try container.decode([Word].self)
        guard let memory = Memory(words: words), words.count == MailboxAddress.count else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Memory must contain exactly \(MailboxAddress.count) words, found \(words.count)"
            )
        }
        self = memory
    }
}
