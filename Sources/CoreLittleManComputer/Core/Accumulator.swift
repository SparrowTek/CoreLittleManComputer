public struct Accumulator: Equatable, Hashable, Sendable, Codable, CustomStringConvertible {
    public static let zero = Accumulator(0)

    public let value: Int

    public var description: String { String(value) }

    public init(_ value: Int) {
        precondition(LMCConstants.signedWordRange.contains(value), "Accumulator must be within -500...499")
        self.value = value
    }

    public init?(exactly value: Int) {
        guard LMCConstants.signedWordRange.contains(value) else { return nil }
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int.self)
        guard LMCConstants.signedWordRange.contains(value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Accumulator must be within -500...499")
        }
        self.value = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
