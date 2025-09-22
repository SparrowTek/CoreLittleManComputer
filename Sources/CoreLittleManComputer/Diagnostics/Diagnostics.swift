public enum ExecutionEvent: Sendable {
    case cycleStarted(cycle: Int, counter: MailboxAddress)
    case instructionDecoded(Instruction)
    case instructionExecuted(Instruction, ProgramState)
    case cycleCompleted(cycle: Int, state: ProgramState)
    case inputRequested
    case outputProduced(Int)
    case breakpointHit(MailboxAddress)
    case halted
    case error(String)
}

public protocol ExecutionObserver: Sendable {
    func handle(_ event: ExecutionEvent)
}

public struct NoOpObserver: ExecutionObserver {
    public init() {}
    public func handle(_ event: ExecutionEvent) {}
}
