public struct ProgramState: Sendable {
    public struct TraceEntry: Equatable, Sendable {
        public let cycle: Int
        public let counter: MailboxAddress
        public let instruction: Instruction?
        public let accumulator: Accumulator
    }

    public private(set) var counter: MailboxAddress
    public private(set) var accumulator: Accumulator
    public private(set) var inbox: [Int]
    public private(set) var outbox: [Int]
    public private(set) var halted: Bool
    public private(set) var cycles: Int
    public private(set) var lastInstruction: Instruction?
    public private(set) var trace: [TraceEntry]

    private let traceLimit: Int

    public init(counter: MailboxAddress = .zero,
                accumulator: Accumulator = .zero,
                inbox: [Int] = [],
                outbox: [Int] = [],
                halted: Bool = false,
                cycles: Int = 0,
                traceLimit: Int = 128) {
        self.counter = counter
        self.accumulator = accumulator
        self.inbox = inbox
        self.outbox = outbox
        self.halted = halted
        self.cycles = cycles
        self.lastInstruction = nil
        self.trace = []
        self.traceLimit = max(0, traceLimit)
    }

    public mutating func advanceCounter(to address: MailboxAddress) {
        counter = address
    }

    public mutating func incrementCounter() {
        counter = counter.advanced(by: 1)
    }

    public mutating func updateAccumulator(_ newValue: Accumulator) {
        accumulator = newValue
    }

    public mutating func enqueueInbox(_ value: Int) {
        inbox.append(value)
    }

    public mutating func dequeueInbox() -> Int? {
        guard !inbox.isEmpty else { return nil }
        return inbox.removeFirst()
    }

    public mutating func emitOutput(_ value: Int) {
        outbox.append(value)
    }

    public mutating func clearOutputs() {
        outbox.removeAll(keepingCapacity: true)
    }

    public mutating func setHalted(_ halted: Bool = true) {
        self.halted = halted
    }

    public mutating func incrementCycle() {
        cycles += 1
    }

    public mutating func record(instruction: Instruction?) {
        lastInstruction = instruction
        let entry = TraceEntry(cycle: cycles,
                               counter: counter,
                               instruction: instruction,
                               accumulator: accumulator)
        trace.append(entry)
        trimTraceBufferIfNeeded()
    }

    public func matchesOutputs(of other: ProgramState) -> Bool {
        outbox == other.outbox
    }

    private mutating func trimTraceBufferIfNeeded() {
        guard traceLimit > 0, trace.count > traceLimit else { return }
        let overflow = trace.count - traceLimit
        trace.removeFirst(overflow)
    }
}
