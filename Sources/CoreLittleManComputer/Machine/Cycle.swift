/// A record of one completed fetch–execute cycle.
///
/// Cycles are what traces, debuggers and animated front-ends consume: they
/// say which mailbox was fetched, what the instruction was, and what it
/// changed. The mailbox an instruction read is simply ``instruction``'s
/// address.
public struct Cycle: Hashable, Sendable, Codable {
    /// The zero-based position of this cycle in the run.
    public var index: Int

    /// The mailbox the instruction was fetched from.
    public var address: MailboxAddress

    /// The instruction that was executed.
    public var instruction: Instruction

    /// The accumulator after the instruction ran.
    public var accumulator: SignedWord

    /// The program counter after the instruction ran.
    public var programCounter: MailboxAddress

    /// `true` when a branch instruction changed the program counter.
    public var branched: Bool

    /// The word written by `STA`, if the instruction was `STA`.
    public var storedWord: Word?

    /// The card taken from the in-basket, if the instruction was `INP`.
    public var input: Word?

    /// The value placed in the out-basket, if the instruction was `OUT`.
    public var output: SignedWord?

    public init(
        index: Int,
        address: MailboxAddress,
        instruction: Instruction,
        accumulator: SignedWord,
        programCounter: MailboxAddress,
        branched: Bool = false,
        storedWord: Word? = nil,
        input: Word? = nil,
        output: SignedWord? = nil
    ) {
        self.index = index
        self.address = address
        self.instruction = instruction
        self.accumulator = accumulator
        self.programCounter = programCounter
        self.branched = branched
        self.storedWord = storedWord
        self.input = input
        self.output = output
    }

    /// The mailbox the instruction wrote, if it was `STA`.
    public var writtenAddress: MailboxAddress? {
        if case .store(let address) = instruction { address } else { nil }
    }

    /// The mailbox the instruction read, if it was `ADD`, `SUB` or `LDA`.
    public var readAddress: MailboxAddress? {
        switch instruction {
        case .add(let address), .subtract(let address), .load(let address): address
        default: nil
        }
    }
}
