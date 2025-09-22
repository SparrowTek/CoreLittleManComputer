public struct ProgramState: Sendable {
    public var counter: MailboxAddress
    public var accumulator: Accumulator
    public var inbox: [Int]
    public var outbox: [Int]
    public var halted: Bool
    public var cycles: Int

    public init(counter: MailboxAddress = MailboxAddress(0),
                accumulator: Accumulator = Accumulator(0),
                inbox: [Int] = [],
                outbox: [Int] = [],
                halted: Bool = false,
                cycles: Int = 0) {
        self.counter = counter
        self.accumulator = accumulator
        self.inbox = inbox
        self.outbox = outbox
        self.halted = halted
        self.cycles = cycles
    }
}
