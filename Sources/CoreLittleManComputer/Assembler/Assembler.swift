public enum AssemblerError: Error, Sendable {
    case notImplemented
}

public struct Assembler: Sendable {
    public init() {}

    public func assemble(_ source: String) throws -> Program {
        throw AssemblerError.notImplemented
    }
}
