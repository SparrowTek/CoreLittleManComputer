import Foundation

extension AsyncStream {
    static func makeStream() -> (stream: AsyncStream<Element>, continuation: AsyncStream<Element>.Continuation) {
        var storedContinuation: AsyncStream<Element>.Continuation!
        let stream = AsyncStream<Element> { continuation in
            storedContinuation = continuation
        }
        return (stream: stream, continuation: storedContinuation)
    }
}
