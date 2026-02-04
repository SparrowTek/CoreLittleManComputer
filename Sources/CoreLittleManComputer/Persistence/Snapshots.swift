import Foundation

public enum SnapshotError: Error, Sendable, Equatable, CustomStringConvertible {
    case invalidWord(Int)
    case invalidMailbox(Int)
    case invalidAccumulator(Int)
    case capacityExceeded(Int)
    case versionMismatch(Int)

    public var description: String {
        switch self {
        case .invalidWord(let value):
            return "Invalid word value: \(value) (must be 0-999)"
        case .invalidMailbox(let value):
            return "Invalid mailbox address: \(value) (must be 0-99)"
        case .invalidAccumulator(let value):
            return "Invalid accumulator value: \(value) (must be -500 to 499)"
        case .capacityExceeded(let count):
            return "Capacity exceeded: \(count) exceeds maximum of 100"
        case .versionMismatch(let version):
            return "Unsupported snapshot version: \(version)"
        }
    }
}

public struct SnapshotMetadata: Codable, Sendable {
    public let schemaVersion: Int
    public let createdAt: Date
    public let generator: String?

    public init(schemaVersion: Int,
                createdAt: Date = Date(),
                generator: String? = SnapshotMetadata.defaultGenerator) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.generator = generator
    }

    public static var defaultGenerator: String {
        ProcessInfo.processInfo.processName
    }
}

public struct ProgramSnapshot: Codable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public let metadata: SnapshotMetadata
    public let words: [Int]
    public let usedCount: Int
    public let labels: [String: Int]

    public init(version: Int = ProgramSnapshot.currentVersion,
                metadata: SnapshotMetadata = SnapshotMetadata(schemaVersion: ProgramSnapshot.currentVersion),
                words: [Int],
                usedCount: Int,
                labels: [String: Int]) {
        self.version = version
        self.metadata = metadata
        self.words = words
        self.usedCount = usedCount
        self.labels = labels
    }

    public init(program: Program) {
        self.init(words: program.memoryImage.map { $0.rawValue },
                  usedCount: program.usedRange.upperBound,
                  labels: program.labels.mapValues { $0.rawValue })
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case metadata
        case words
        case usedCount
        case labels
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedVersion = try container.decodeIfPresent(Int.self, forKey: .version) ?? ProgramSnapshot.currentVersion
        self.version = decodedVersion
        if let metadata = try container.decodeIfPresent(SnapshotMetadata.self, forKey: .metadata) {
            self.metadata = metadata
        } else {
            self.metadata = SnapshotMetadata(schemaVersion: decodedVersion)
        }
        self.words = try container.decode([Int].self, forKey: .words)
        self.usedCount = try container.decode(Int.self, forKey: .usedCount)
        self.labels = try container.decode([String: Int].self, forKey: .labels)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(words, forKey: .words)
        try container.encode(usedCount, forKey: .usedCount)
        try container.encode(labels, forKey: .labels)
    }
}

public struct ProgramStateSnapshot: Codable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public let metadata: SnapshotMetadata
    public let counter: Int
    public let accumulator: Int
    public let inbox: [Int]
    public let outbox: [Int]
    public let halted: Bool
    public let cycles: Int
    public let memory: [Int]

    public init(version: Int = ProgramStateSnapshot.currentVersion,
                metadata: SnapshotMetadata = SnapshotMetadata(schemaVersion: ProgramStateSnapshot.currentVersion),
                counter: Int,
                accumulator: Int,
                inbox: [Int],
                outbox: [Int],
                halted: Bool,
                cycles: Int,
                memory: [Int]) {
        self.version = version
        self.metadata = metadata
        self.counter = counter
        self.accumulator = accumulator
        self.inbox = inbox
        self.outbox = outbox
        self.halted = halted
        self.cycles = cycles
        self.memory = memory
    }

    public init(state: ProgramState) {
        self.init(counter: state.counter.rawValue,
                  accumulator: state.accumulator.value,
                  inbox: state.inbox,
                  outbox: state.outbox,
                  halted: state.halted,
                  cycles: state.cycles,
                  memory: state.memorySnapshot.map { $0.rawValue })
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case metadata
        case counter
        case accumulator
        case inbox
        case outbox
        case halted
        case cycles
        case memory
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedVersion = try container.decodeIfPresent(Int.self, forKey: .version) ?? ProgramStateSnapshot.currentVersion
        self.version = decodedVersion
        if let metadata = try container.decodeIfPresent(SnapshotMetadata.self, forKey: .metadata) {
            self.metadata = metadata
        } else {
            self.metadata = SnapshotMetadata(schemaVersion: decodedVersion)
        }
        self.counter = try container.decode(Int.self, forKey: .counter)
        self.accumulator = try container.decode(Int.self, forKey: .accumulator)
        self.inbox = try container.decode([Int].self, forKey: .inbox)
        self.outbox = try container.decode([Int].self, forKey: .outbox)
        self.halted = try container.decode(Bool.self, forKey: .halted)
        self.cycles = try container.decode(Int.self, forKey: .cycles)
        self.memory = try container.decode([Int].self, forKey: .memory)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(counter, forKey: .counter)
        try container.encode(accumulator, forKey: .accumulator)
        try container.encode(inbox, forKey: .inbox)
        try container.encode(outbox, forKey: .outbox)
        try container.encode(halted, forKey: .halted)
        try container.encode(cycles, forKey: .cycles)
        try container.encode(memory, forKey: .memory)
    }
}

public extension Program {
    init(snapshot: ProgramSnapshot) throws {
        guard snapshot.version <= ProgramSnapshot.currentVersion else {
            throw SnapshotError.versionMismatch(snapshot.version)
        }
        guard snapshot.usedCount <= Program.capacity else {
            throw SnapshotError.capacityExceeded(snapshot.usedCount)
        }

        var storage: [Word] = []
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

    func snapshot(metadata: SnapshotMetadata = SnapshotMetadata(schemaVersion: ProgramSnapshot.currentVersion)) -> ProgramSnapshot {
        ProgramSnapshot(version: ProgramSnapshot.currentVersion,
                        metadata: metadata,
                        words: memoryImage.map { $0.rawValue },
                        usedCount: usedRange.upperBound,
                        labels: labels.mapValues { $0.rawValue })
    }
}

public extension ProgramState {
    init(snapshot: ProgramStateSnapshot) throws {
        guard snapshot.version <= ProgramStateSnapshot.currentVersion else {
            throw SnapshotError.versionMismatch(snapshot.version)
        }
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

    func snapshot(metadata: SnapshotMetadata = SnapshotMetadata(schemaVersion: ProgramStateSnapshot.currentVersion)) -> ProgramStateSnapshot {
        ProgramStateSnapshot(version: ProgramStateSnapshot.currentVersion,
                             metadata: metadata,
                             counter: counter.rawValue,
                             accumulator: accumulator.value,
                             inbox: inbox,
                             outbox: outbox,
                             halted: halted,
                             cycles: cycles,
                             memory: memorySnapshot.map { $0.rawValue })
    }
}
