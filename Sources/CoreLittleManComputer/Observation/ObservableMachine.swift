#if canImport(Observation)
import Observation

/// A main-actor mirror of an ``ExecutionEngine`` for SwiftUI and other
/// observation-driven front-ends.
///
/// Place it in the environment and read ``machine``, ``lastCycle`` and
/// ``isRunning`` from views. Keep it current with a task modifier:
///
/// ```swift
/// .task { await observable.observe() }
/// ```
///
/// ``observe()`` returns when the task is cancelled, so the view's lifetime
/// bounds the subscription. The forwarding methods are conveniences; calling
/// the engine directly works just as well and is reflected here.
@MainActor
@Observable
public final class ObservableMachine {
    /// The engine being mirrored.
    public let engine: ExecutionEngine

    /// The most recent machine state.
    public private(set) var machine: Machine

    /// Why ``machine`` last changed.
    public private(set) var lastChange: MachineChange?

    /// The most recently executed cycle, cleared by a reset or load.
    public private(set) var lastCycle: Cycle?

    /// `true` while the engine is running.
    public private(set) var isRunning = false

    /// How the most recent run ended, or `nil` while running or before any run.
    public private(set) var lastRunOutcome: RunOutcome?

    /// `true` while ``observe()`` is receiving events from the engine.
    public var isObserving: Bool {
        observerCount > 0
    }

    private var observerCount = 0

    /// Creates an engine for `program` and mirrors it.
    public init(
        program: Program,
        inbox: [Word] = [],
        overflowBehavior: OverflowBehavior = .fault
    ) {
        machine = Machine(program: program, inbox: inbox, overflowBehavior: overflowBehavior)
        engine = ExecutionEngine(program: program, inbox: inbox, overflowBehavior: overflowBehavior)
    }

    /// Mirrors an existing engine.
    public init(engine: ExecutionEngine) async {
        self.engine = engine
        self.machine = await engine.machine
    }

    /// Keeps this object current until the calling task is cancelled.
    ///
    /// Everything this object publishes comes from the engine's event stream,
    /// so it is only up to date while a task is inside this method.
    public func observe() async {
        let events = await engine.events(bufferingPolicy: .bufferingNewest(256))
        observerCount += 1
        defer { observerCount -= 1 }
        for await event in events {
            apply(event)
        }
    }

    private func apply(_ event: ExecutionEvent) {
        switch event {
        case .machineChanged(let machine, let cause):
            self.machine = machine
            lastChange = cause
            switch cause {
            case .cycle(let cycle):
                lastCycle = cycle
            case .reset, .programLoaded:
                lastCycle = nil
            case .snapshot, .awaitingInput, .fault, .inputProvided, .edited:
                break
            }
        case .runStarted:
            isRunning = true
            lastRunOutcome = nil
        case .runFinished(let outcome):
            isRunning = false
            lastRunOutcome = outcome
        }
    }

    // MARK: - Forwarding

    /// Executes one instruction.
    @discardableResult
    public func step() async -> StepOutcome {
        await engine.step()
    }

    /// Runs until the program stops or ``pause()`` is called.
    @discardableResult
    public func run(speed: ExecutionSpeed = .maximum, maxCycles: Int? = nil) async -> RunOutcome {
        await engine.run(speed: speed, maxCycles: maxCycles)
    }

    /// Ends the run in progress.
    public func pause() async {
        await engine.pause()
    }

    /// Returns the machine to the start of the current program.
    public func reset(inbox: [Word] = []) async {
        await engine.reset(inbox: inbox)
    }

    /// Replaces the program.
    public func load(_ program: Program, inbox: [Word] = []) async {
        await engine.load(program, inbox: inbox)
    }

    /// Places a card in the in-basket.
    public func provideInput(_ word: Word) async {
        await engine.provideInput(word)
    }

    /// Writes `word` into the mailbox at `address`.
    public func write(_ word: Word, at address: MailboxAddress) async {
        await engine.write(word, at: address)
    }
}
#endif
