public struct Accumulator: Equatable, Hashable, Sendable {
    public let value: Int

    public init(_ value: Int) {
        precondition(LMCConstants.signedWordRange.contains(value), "Accumulator must be within -500...499")
        self.value = value
    }
}
