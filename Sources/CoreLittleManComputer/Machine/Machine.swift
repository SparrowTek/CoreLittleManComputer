/// The Little Man Computer as a value: 100 mailboxes, the accumulator, the
/// program counter, the in-basket and the out-basket.
///
/// `Machine` is deterministic and has no reference semantics, so a copy is a
/// snapshot, equality is structural, and it can be encoded, compared and
/// passed between tasks freely. ``step()`` performs exactly one fetch–execute
/// cycle; ``ExecutionEngine`` drives a machine over time.
///
/// ## Semantics
///
/// - Mailboxes hold unsigned three-digit ``Word``s. The accumulator holds a
///   ``SignedWord``, `-999` through `999`.
/// - `LDA` and `INP` place a mailbox or card value in the accumulator unchanged.
/// - `ADD` and `SUB` compute the exact result. If it fits the accumulator it is
///   kept; otherwise ``overflowBehavior`` decides between faulting and wrapping.
/// - `STA` stores ``SignedWord/storedWord``: non-negative values as they are,
///   negative values in ten's complement, so `-1` is stored as `999`.
/// - `BRZ` branches when the accumulator is exactly zero. `BRP` branches when
///   it is zero or positive.
/// - `INP` with an empty in-basket leaves the machine ``MachineStatus/awaitingInput``
///   with the program counter still on the `INP` instruction.
/// - The program counter is incremented after the fetch, before execution, so
///   after `HLT` it points one past the halt. It wraps from `99` to `00`.
/// - Any word from `000` to `099` executes as `HLT`. `4xx` words and `9xx`
///   words other than `901` and `902` raise ``MachineFault/invalidInstruction(word:address:)``.
public struct Machine: Hashable, Sendable, Codable {
    /// The 100 mailboxes.
    public var memory: Memory

    /// The calculator the Little Man works with.
    public var accumulator: SignedWord

    /// The mailbox the next instruction will be fetched from.
    public var programCounter: MailboxAddress

    /// Cards waiting to be read by `INP`, first in first out.
    public var inbox: [Word]

    /// Values produced by `OUT`, oldest first.
    public var outbox: [SignedWord]

    /// Whether the machine can execute its next instruction.
    public var status: MachineStatus

    /// The number of instructions executed so far.
    public var cycleCount: Int

    /// What happens when arithmetic leaves the accumulator's range.
    public var overflowBehavior: OverflowBehavior

    /// Creates a machine at rest with the given memory image and in-basket.
    public init(
        memory: Memory = .empty,
        inbox: [Word] = [],
        overflowBehavior: OverflowBehavior = .fault
    ) {
        self.memory = memory
        self.accumulator = .zero
        self.programCounter = .zero
        self.inbox = inbox
        self.outbox = []
        self.status = .ready
        self.cycleCount = 0
        self.overflowBehavior = overflowBehavior
    }

    /// Creates a machine loaded with `program` and at rest at mailbox `00`.
    public init(
        program: Program,
        inbox: [Word] = [],
        overflowBehavior: OverflowBehavior = .fault
    ) {
        self.init(memory: program.memory, inbox: inbox, overflowBehavior: overflowBehavior)
    }

    /// `true` when ``step()`` would execute an instruction rather than wait or do nothing.
    public var canStep: Bool {
        switch status {
        case .ready: true
        case .awaitingInput: !inbox.isEmpty
        case .halted, .faulted: false
        }
    }

    /// The instruction the program counter points at, or `nil` when that
    /// word is not an instruction.
    public var nextInstruction: Instruction? {
        Instruction(word: memory[programCounter])
    }

    /// Places a card at the back of the in-basket and, if the machine was
    /// waiting for input, makes it ready again.
    public mutating func provideInput(_ word: Word) {
        inbox.append(word)
        if status == .awaitingInput {
            status = .ready
        }
    }

    /// Performs one fetch–execute cycle.
    ///
    /// The outcome says what happened; ``status`` says what can happen next.
    /// A halted or faulted machine returns ``StepOutcome/notRunning`` and
    /// stays unchanged.
    @discardableResult
    public mutating func step() -> StepOutcome {
        switch status {
        case .halted, .faulted:
            return .notRunning
        case .ready, .awaitingInput:
            status = .ready
        }

        let address = programCounter
        let word = memory[address]
        guard let instruction = Instruction(word: word) else {
            return fault(.invalidInstruction(word: word, address: address))
        }

        var cycle = Cycle(
            index: cycleCount,
            address: address,
            instruction: instruction,
            accumulator: accumulator,
            programCounter: address.successor
        )

        switch instruction {
        case .add(let operand):
            let sum = accumulator.rawValue + memory[operand].rawValue
            guard let result = accumulatorValue(for: sum) else {
                return fault(.accumulatorOverflow(value: sum, address: address))
            }
            accumulator = result

        case .subtract(let operand):
            let difference = accumulator.rawValue - memory[operand].rawValue
            guard let result = accumulatorValue(for: difference) else {
                return fault(.accumulatorOverflow(value: difference, address: address))
            }
            accumulator = result

        case .store(let operand):
            let stored = accumulator.storedWord
            memory[operand] = stored
            cycle.storedWord = stored

        case .load(let operand):
            accumulator = SignedWord(memory[operand])

        case .branchAlways(let target):
            cycle.programCounter = target
            cycle.branched = true

        case .branchIfZero(let target):
            if accumulator.isZero {
                cycle.programCounter = target
                cycle.branched = true
            }

        case .branchIfPositive(let target):
            if !accumulator.isNegative {
                cycle.programCounter = target
                cycle.branched = true
            }

        case .input:
            guard !inbox.isEmpty else {
                status = .awaitingInput
                return .awaitingInput
            }
            let card = inbox.removeFirst()
            accumulator = SignedWord(card)
            cycle.input = card

        case .output:
            outbox.append(accumulator)
            cycle.output = accumulator

        case .halt:
            status = .halted
        }

        cycle.accumulator = accumulator
        programCounter = cycle.programCounter
        cycleCount += 1
        return .executed(cycle)
    }

    /// Executes instructions until the machine halts, faults, needs input,
    /// or `maxCycles` instructions have run.
    ///
    /// The limit protects callers from programs that never halt. For paced or
    /// interruptible execution use ``ExecutionEngine``.
    @discardableResult
    public mutating func run(maxCycles: Int = 100_000) -> RunOutcome {
        if case .faulted(let fault) = status {
            return .faulted(fault)
        }
        if status == .halted {
            return .halted
        }

        var executed = 0
        while executed < maxCycles {
            switch step() {
            case .executed:
                executed += 1
                if status == .halted {
                    return .halted
                }
            case .awaitingInput:
                return .awaitingInput
            case .faulted(let fault):
                return .faulted(fault)
            case .notRunning:
                if case .faulted(let fault) = status {
                    return .faulted(fault)
                }
                return .halted
            }
        }
        return .cycleLimitReached
    }

    private func accumulatorValue(for result: Int) -> SignedWord? {
        if let exact = SignedWord(rawValue: result) {
            return exact
        }
        switch overflowBehavior {
        case .fault: return nil
        case .wrap: return SignedWord(wrapping: result)
        }
    }

    private mutating func fault(_ fault: MachineFault) -> StepOutcome {
        status = .faulted(fault)
        return .faulted(fault)
    }
}
