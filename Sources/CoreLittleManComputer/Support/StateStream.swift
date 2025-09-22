import Foundation

public extension ExecutionEngine {
    /// Produces an async stream of program states as the engine executes.
    /// - Parameter emitInitial: When true, the current state is yielded immediately.
    func stateStream(emitInitial: Bool = true) -> AsyncStream<ProgramState> {
        AsyncStream { continuation in
            if emitInitial {
                continuation.yield(state)
            }

            let task = Task {
                for await event in events {
                    switch event {
                    case .cycleCompleted(_, let snapshot):
                        continuation.yield(snapshot)
                    case .halted:
                        continuation.yield(state)
                        continuation.finish()
                        return
                    default:
                        break
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
