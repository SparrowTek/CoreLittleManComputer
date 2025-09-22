public protocol InboxProviding: Sendable {
    mutating func dequeue() -> Int?
}

public protocol OutboxConsuming: Sendable {
    mutating func enqueue(_ value: Int)
}

public struct ArrayInbox: InboxProviding {
    private var storage: [Int]

    public init(_ values: [Int]) {
        self.storage = values
    }

    public mutating func dequeue() -> Int? {
        storage.isEmpty ? nil : storage.removeFirst()
    }
}

public struct ArrayOutbox: OutboxConsuming {
    private(set) public var storage: [Int]

    public init() {
        self.storage = []
    }

    public mutating func enqueue(_ value: Int) {
        storage.append(value)
    }
}
