public struct Word: Equatable, Hashable, Sendable, Codable, CustomStringConvertible {
    public static let digits = 3
    public static let zero = Word(0)

    public let rawValue: Int

    public init(_ rawValue: Int) {
        precondition(LMCConstants.wordRange.contains(rawValue), "Word must be within 0...999")
        self.rawValue = rawValue
    }

    public init?(exactly rawValue: Int) {
        guard LMCConstants.wordRange.contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init(signedValue: Int) {
        precondition(LMCConstants.signedWordRange.contains(signedValue), "Signed word must be within -500...499")
        if signedValue >= 0 {
            self.rawValue = signedValue
        } else {
            self.rawValue = LMCConstants.decimalBase + signedValue
        }
    }

    public init?(signedExactly value: Int) {
        guard LMCConstants.signedWordRange.contains(value) else { return nil }
        if value >= 0 {
            self.rawValue = value
        } else {
            self.rawValue = LMCConstants.decimalBase + value
        }
    }

    public var signedValue: Int {
        rawValue <= LMCConstants.signedWordRange.upperBound ? rawValue : rawValue - LMCConstants.decimalBase
    }

    public var description: String { zeroPaddedString }

    public var zeroPaddedString: String {
        let formatted = String(rawValue)
        guard formatted.count < Self.digits else { return formatted }
        return String(repeating: "0", count: Self.digits - formatted.count) + formatted
    }

    public var highDigit: Int {
        rawValue / 100
    }

    public var lowValue: Int {
        rawValue % 100
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int.self)
        guard LMCConstants.wordRange.contains(value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Word must be within 0...999")
        }
        self.rawValue = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
