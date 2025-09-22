#if canImport(Observation)
import Observation

@Observable
public final class ObservableProgramState {
    public private(set) var state: ProgramState
    private let engine: ExecutionEngine
    private var streamTask: Task<Void, Never>?

    public init(engine: ExecutionEngine) {
        self.engine = engine
        self.state = engine.state
    }

    deinit {
        streamTask?.cancel()
    }

    public func startStreaming(emitInitial: Bool = true) {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            let stream = engine.stateStream(emitInitial: emitInitial)
            for await state in stream {
                await MainActor.run {
                    self.state = state
                }
            }
        }
    }

    public func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
    }
}
#endif
