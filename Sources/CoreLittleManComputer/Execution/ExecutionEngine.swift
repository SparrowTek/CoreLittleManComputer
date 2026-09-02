/// Drives a ``Machine`` over time.
///
/// The engine owns a machine and the program it was loaded from, and adds
/// what a front-end needs beyond single steps: paced running that can be
/// paused, breakpoints, a bounded trace of executed cycles, and a stream of
/// ``ExecutionEvent``s that any number of observers can subscribe to.
///
/// Because the engine is an actor, every call is serialised and safe from any
/// task. ``run(speed:maxCycles:)`` suspends between instructions, so calls
/// such as ``pause()`` and ``provideInput(_:)`` get through while it runs.
///
/// ```swift
/// let program = try Assembler().assemble(source)
/// let engine = ExecutionEngine(program: program, inbox: [5, 3])
/// let outcome = await engine.run(speed: .hertz(4))
/// let outputs = await engine.machine.outbox
/// ```
public actor ExecutionEngine {
    /// The program the machine was loaded from; ``reset(inbox:)`` returns to it.
    public private(set) var program: Program

    /// The current machine state.
    public private(set) var machine: Machine

    /// Mailboxes at which ``run(speed:maxCycles:)`` stops before executing.
    public private(set) var breakpoints: Set<MailboxAddress> = []

    /// `true` while a run is in progress.
    public private(set) var isRunning = false

    /// The most recently executed cycles, oldest first, at most ``traceLimit`` of them.
    public private(set) var trace: [Cycle] = []

    /// The maximum number of cycles kept in ``trace``.
    public nonisolated let traceLimit: Int

    private var subscribers: [Int: AsyncStream<ExecutionEvent>.Continuation] = [:]
    private var nextSubscriberID = 0
    private var stopRequested = false

    /// Creates an engine with `program` loaded and the machine at rest at mailbox `00`.
    public init(
        program: Program,
        inbox: [Word] = [],
        overflowBehavior: OverflowBehavior = .fault,
        traceLimit: Int = 1_000
    ) {
        self.program = program
        self.machine = Machine(program: program, inbox: inbox, overflowBehavior: overflowBehavior)
        self.traceLimit = max(0, traceLimit)
    }

    deinit {
        for continuation in subscribers.values {
            continuation.finish()
        }
    }

    // MARK: - Observing

    /// A stream of everything that happens to the machine.
    ///
    /// The first element is always a ``MachineChange/snapshot`` of the current
    /// state, so a subscriber never starts out of date. Each subscriber gets
    /// its own stream; the stream ends when the engine is deallocated or the
    /// subscriber stops iterating.
    ///
    /// - Parameter bufferingPolicy: How to buffer events for a slow consumer.
    ///   User interfaces that only need the latest state can pass
    ///   `.bufferingNewest(1)`; traces should keep the default.
    public func events(
        bufferingPolicy: AsyncStream<ExecutionEvent>.Continuation.BufferingPolicy = .unbounded
    ) -> AsyncStream<ExecutionEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: ExecutionEvent.self, bufferingPolicy: bufferingPolicy)
        continuation.yield(.machineChanged(machine, cause: .snapshot))
        subscribers[nextSubscriberID] = continuation
        nextSubscriberID += 1
        return stream
    }

    private func publish(_ event: ExecutionEvent) {
        for (id, continuation) in subscribers {
            if case .terminated = continuation.yield(event) {
                subscribers[id] = nil
            }
        }
    }

    private func publishMachine(_ cause: MachineChange) {
        publish(.machineChanged(machine, cause: cause))
    }

    // MARK: - Loading

    /// Replaces the program and starts a fresh machine for it.
    ///
    /// A run in progress stops with ``RunOutcome/paused``.
    public func load(_ program: Program, inbox: [Word] = []) {
        self.program = program
        restart(inbox: inbox, cause: .programLoaded)
    }

    /// Returns the machine to its starting state for the current program.
    ///
    /// A run in progress stops with ``RunOutcome/paused``.
    public func reset(inbox: [Word] = []) {
        restart(inbox: inbox, cause: .reset)
    }

    private func restart(inbox: [Word], cause: MachineChange) {
        stopRequested = true
        machine = Machine(program: program, inbox: inbox, overflowBehavior: machine.overflowBehavior)
        trace.removeAll()
        publishMachine(cause)
    }

    /// Changes what happens when arithmetic leaves the accumulator's range.
    public func setOverflowBehavior(_ behavior: OverflowBehavior) {
        machine.overflowBehavior = behavior
        publishMachine(.edited)
    }

    // MARK: - Input and editing

    /// Places a card in the in-basket. If the machine was waiting for input it
    /// becomes ready, and a run can be resumed.
    public func provideInput(_ word: Word) {
        machine.provideInput(word)
        publishMachine(.inputProvided(word))
    }

    /// Changes the machine directly, for debuggers and editors.
    public func edit(_ change: @Sendable (inout Machine) -> Void) {
        change(&machine)
        publishMachine(.edited)
    }

    /// Writes `word` into the mailbox at `address`.
    public func write(_ word: Word, at address: MailboxAddress) {
        edit { $0.memory[address] = word }
    }

    // MARK: - Breakpoints

    /// Replaces every breakpoint.
    public func setBreakpoints(_ addresses: Set<MailboxAddress>) {
        breakpoints = addresses
    }

    /// Adds a breakpoint at `address`.
    public func addBreakpoint(_ address: MailboxAddress) {
        breakpoints.insert(address)
    }

    /// Removes the breakpoint at `address`, if there is one.
    public func removeBreakpoint(_ address: MailboxAddress) {
        breakpoints.remove(address)
    }

    /// Adds a breakpoint at `address` if there is none, otherwise removes it.
    /// Returns `true` when a breakpoint is now set there.
    @discardableResult
    public func toggleBreakpoint(_ address: MailboxAddress) -> Bool {
        if breakpoints.remove(address) == nil {
            breakpoints.insert(address)
            return true
        }
        return false
    }

    /// Removes every breakpoint.
    public func clearBreakpoints() {
        breakpoints.removeAll()
    }

    // MARK: - Executing

    /// Executes one instruction, ignoring breakpoints.
    @discardableResult
    public func step() -> StepOutcome {
        let outcome = machine.step()
        record(outcome)
        return outcome
    }

    /// Executes instructions until the program halts, faults, needs input,
    /// reaches a breakpoint, reaches `maxCycles`, or is paused.
    ///
    /// The instruction at the current program counter is always executed
    /// even if it carries a breakpoint, so a run can be resumed from the
    /// breakpoint it stopped at. Cancelling the calling task ends the run
    /// with ``RunOutcome/paused``.
    @discardableResult
    public func run(speed: ExecutionSpeed = .maximum, maxCycles: Int? = nil) async -> RunOutcome {
        await run(speed: speed, maxCycles: maxCycles, clock: ContinuousClock())
    }

    /// Like ``run(speed:maxCycles:)``, pacing execution with `clock`.
    @discardableResult
    public func run(
        speed: ExecutionSpeed,
        maxCycles: Int?,
        clock: some Clock<Duration>
    ) async -> RunOutcome {
        guard !isRunning else { return .alreadyRunning }
        isRunning = true
        stopRequested = false
        publish(.runStarted)

        let outcome = await execute(speed: speed, maxCycles: maxCycles, clock: clock)

        isRunning = false
        publish(.runFinished(outcome))
        return outcome
    }

    /// Ends the run in progress, if any, with ``RunOutcome/paused``.
    public func pause() {
        stopRequested = true
    }

    /// Forgets the recorded cycles.
    public func clearTrace() {
        trace.removeAll()
    }

    private func execute(
        speed: ExecutionSpeed,
        maxCycles: Int?,
        clock: some Clock<Duration>
    ) async -> RunOutcome {
        var executed = 0
        var isResuming = true

        while true {
            if stopRequested || Task.isCancelled {
                return .paused
            }
            if let maxCycles, executed >= maxCycles {
                return .cycleLimitReached
            }
            switch machine.status {
            case .halted:
                return .halted
            case .faulted(let fault):
                return .faulted(fault)
            case .ready, .awaitingInput:
                break
            }
            if !isResuming, breakpoints.contains(machine.programCounter) {
                return .breakpoint(machine.programCounter)
            }
            isResuming = false

            switch step() {
            case .executed:
                executed += 1
            case .awaitingInput:
                return .awaitingInput
            case .faulted(let fault):
                return .faulted(fault)
            case .notRunning:
                continue
            }

            switch speed {
            case .maximum:
                if executed.isMultiple(of: 256) {
                    await Task.yield()
                }
            case .cycleDuration(let duration):
                do {
                    try await clock.sleep(for: duration)
                } catch {
                    return .paused
                }
            }
        }
    }

    private func record(_ outcome: StepOutcome) {
        switch outcome {
        case .executed(let cycle):
            trace.append(cycle)
            if trace.count > traceLimit {
                trace.removeFirst(trace.count - traceLimit)
            }
            publishMachine(.cycle(cycle))
        case .awaitingInput:
            publishMachine(.awaitingInput)
        case .faulted(let fault):
            publishMachine(.fault(fault))
        case .notRunning:
            break
        }
    }
}
