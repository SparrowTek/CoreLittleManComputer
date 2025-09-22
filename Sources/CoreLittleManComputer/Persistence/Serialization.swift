import Foundation

public enum ProgramSerializationError: Error, Sendable {
    case notImplemented
}

public struct ProgramSerializer: Sendable {
    public init() {}

    public func exportJSON(_ program: Program) throws -> Data {
        throw ProgramSerializationError.notImplemented
    }
}
