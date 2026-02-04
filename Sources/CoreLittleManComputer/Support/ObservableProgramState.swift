#if canImport(Observation)
import Observation

@MainActor
@Observable
public final class ObservableProgramState {
    public private(set) var state: ProgramState
    private let engine: ExecutionEngine
    private var streamTask: Task<Void, Never>?
    private nonisolated(unsafe) var cancellableTask: Task<Void, Never>?

    public init(engine: ExecutionEngine) {
        self.engine = engine
        self.state = engine.state
    }

    deinit {
        cancellableTask?.cancel()
    }

    public func startStreaming(emitInitial: Bool = true) {
        streamTask?.cancel()
        let engine = self.engine
        let task = Task { [weak self] in
            let stream = engine.stateStream(emitInitial: emitInitial)
            for await state in stream {
                self?.state = state
            }
        }
        streamTask = task
        cancellableTask = task
    }

    public func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        cancellableTask = nil
    }
}
#endif
