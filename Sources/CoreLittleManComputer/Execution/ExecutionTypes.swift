/// How quickly ``ExecutionEngine/run(speed:maxCycles:)`` executes instructions.
public enum ExecutionSpeed: Hashable, Sendable {
    /// Run as fast as possible, yielding periodically so the engine stays responsive.
    case maximum

    /// Wait this long after every instruction.
    case cycleDuration(Duration)

    /// Execute `cyclesPerSecond` instructions each second.
    ///
    /// Zero, negative and non-finite rates mean ``maximum``.
    public static func hertz(_ cyclesPerSecond: Double) -> ExecutionSpeed {
        guard cyclesPerSecond > 0, cyclesPerSecond.isFinite else { return .maximum }
        return .cycleDuration(.seconds(1 / cyclesPerSecond))
    }

    /// The pause after each instruction, or `nil` for ``maximum``.
    public var cycleDuration: Duration? {
        switch self {
        case .maximum: nil
        case .cycleDuration(let duration): duration
        }
    }
}

/// Why an ``ExecutionEngine`` published a new machine state.
public enum MachineChange: Hashable, Sendable {
    /// The state a new subscriber receives first.
    case snapshot

    /// One instruction executed.
    case cycle(Cycle)

    /// `INP` found the in-basket empty.
    case awaitingInput

    /// The program caused a fault.
    case fault(MachineFault)

    /// A card was added to the in-basket.
    case inputProvided(Word)

    /// A different program was loaded.
    case programLoaded

    /// The machine was returned to its starting state.
    case reset

    /// The machine was changed directly through ``ExecutionEngine/edit(_:)``.
    case edited
}

/// Something an ``ExecutionEngine`` tells its subscribers.
public enum ExecutionEvent: Hashable, Sendable {
    /// The machine changed; the full new state is included so no subscriber
    /// ever needs to reconstruct it from earlier events.
    case machineChanged(Machine, cause: MachineChange)

    /// A run began.
    case runStarted

    /// A run ended, and why.
    case runFinished(RunOutcome)

    /// The machine state carried by the event, if it has one.
    public var machine: Machine? {
        if case .machineChanged(let machine, _) = self { machine } else { nil }
    }
}
