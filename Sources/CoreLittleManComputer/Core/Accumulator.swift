public struct Accumulator: Equatable, Hashable, Sendable {
    public static let zero = Accumulator(0)

    public let value: Int

    public init(_ value: Int) {
        precondition(LMCConstants.signedWordRange.contains(value), "Accumulator must be within -500...499")
        self.value = value
    }

    public func adding(_ other: Int, policy: NumericPolicy) throws -> Accumulator {
        try policy.accumulator(from: value + other)
    }

    public func adding(word other: Word, policy: NumericPolicy) throws -> Accumulator {
        try adding(other.signedValue, policy: policy)
    }

    public func subtracting(word other: Word, policy: NumericPolicy) throws -> Accumulator {
        try adding(-other.signedValue, policy: policy)
    }
}
