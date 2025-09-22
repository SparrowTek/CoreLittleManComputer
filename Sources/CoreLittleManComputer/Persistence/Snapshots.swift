import Foundation

public enum SnapshotError: Error, Sendable {
    case invalidWord(Int)
    case invalidMailbox(Int)
    case invalidAccumulator(Int)
    case capacityExceeded(Int)
}

public struct ProgramSnapshot: Codable, Sendable {
    public let words: [Int]
    public let usedCount: Int
    public let labels: [String: Int]

    public init(program: Program) {
        self.words = program.memoryImage.map { $0.rawValue }
        self.usedCount = program.usedRange.upperBound
        self.labels = program.labels.mapValues { $0.rawValue }
    }

    public init(words: [Int], usedCount: Int, labels: [String: Int]) {
        self.words = words
        self.usedCount = usedCount
        self.labels = labels
    }
}

public struct ProgramStateSnapshot: Codable, Sendable {
    public let counter: Int
    public let accumulator: Int
    public let inbox: [Int]
    public let outbox: [Int]
    public let halted: Bool
    public let cycles: Int
    public let memory: [Int]

    public init(state: ProgramState) {
        self.counter = state.counter.rawValue
        self.accumulator = state.accumulator.value
        self.inbox = state.inbox
        self.outbox = state.outbox
        self.halted = state.halted
        self.cycles = state.cycles
        self.memory = state.memorySnapshot.map { $0.rawValue }
    }

    public init(counter: Int,
                accumulator: Int,
                inbox: [Int],
                outbox: [Int],
                halted: Bool,
                cycles: Int,
                memory: [Int]) {
        self.counter = counter
        self.accumulator = accumulator
        self.inbox = inbox
        self.outbox = outbox
        self.halted = halted
        self.cycles = cycles
        self.memory = memory
    }
}

public extension Program {
    init(snapshot: ProgramSnapshot) throws {
        guard snapshot.usedCount <= Program.capacity else {
            throw SnapshotError.capacityExceeded(snapshot.usedCount)
        }

        var storage = [Word]()
        storage.reserveCapacity(snapshot.words.count)
        for value in snapshot.words {
            guard LMCConstants.wordRange.contains(value) else {
                throw SnapshotError.invalidWord(value)
            }
            storage.append(Word(value))
        }
        guard storage.count >= snapshot.usedCount else {
            throw SnapshotError.capacityExceeded(snapshot.usedCount)
        }
        if storage.count < Program.capacity {
            storage.append(contentsOf: Array(repeating: Word.zero, count: Program.capacity - storage.count))
        }

        var labelMap: [String: MailboxAddress] = [:]
        for (label, index) in snapshot.labels {
            guard MailboxAddress.validRange.contains(index) else {
                throw SnapshotError.invalidMailbox(index)
            }
            labelMap[label] = MailboxAddress(index)
        }

        self.init(words: Array(storage.prefix(snapshot.usedCount)), labels: labelMap)
    }

    func snapshot() -> ProgramSnapshot {
        ProgramSnapshot(program: self)
    }
}

public extension ProgramState {
    init(snapshot: ProgramStateSnapshot) throws {
        guard MailboxAddress.validRange.contains(snapshot.counter) else {
            throw SnapshotError.invalidMailbox(snapshot.counter)
        }
        guard LMCConstants.signedWordRange.contains(snapshot.accumulator) else {
            throw SnapshotError.invalidAccumulator(snapshot.accumulator)
        }
        guard snapshot.memory.count == Program.capacity else {
            throw SnapshotError.capacityExceeded(snapshot.memory.count)
        }

        var memoryWords: [Word] = []
        memoryWords.reserveCapacity(snapshot.memory.count)
        for value in snapshot.memory {
            guard LMCConstants.wordRange.contains(value) else {
                throw SnapshotError.invalidWord(value)
            }
            memoryWords.append(Word(value))
        }

        self.init(counter: MailboxAddress(snapshot.counter),
                  accumulator: Accumulator(snapshot.accumulator),
                  inbox: snapshot.inbox,
                  outbox: snapshot.outbox,
                  halted: snapshot.halted,
                  cycles: snapshot.cycles,
                  memory: memoryWords)
    }

    func snapshot() -> ProgramStateSnapshot {
        ProgramStateSnapshot(state: self)
    }
}
