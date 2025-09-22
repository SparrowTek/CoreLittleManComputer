public enum ExecutionError: Error, Sendable {
    case halted
    case awaitingInput
    case invalidState(String)
    case notImplemented
}

public final class ExecutionEngine: @unchecked Sendable {
    public let program: Program
    public let numericPolicy: NumericPolicy
    private(set) public var state: ProgramState

    public init(program: Program, initialState: ProgramState = ProgramState(), numericPolicy: NumericPolicy = .trapOnOverflow) {
        self.program = program
        self.state = initialState
        self.numericPolicy = numericPolicy
    }

    public func step() throws {
        throw ExecutionError.notImplemented
    }
}
