public struct Word: Equatable, Hashable, Sendable, Codable {
    public static let digits = 3
    public static let zero = Word(0)

    public let rawValue: Int

    public init(_ rawValue: Int) {
        precondition(LMCConstants.wordRange.contains(rawValue), "Word must be within 0...999")
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

    public var signedValue: Int {
        rawValue <= LMCConstants.signedWordRange.upperBound ? rawValue : rawValue - LMCConstants.decimalBase
    }

    public var zeroPaddedString: String {
        let description = String(rawValue)
        guard description.count < Self.digits else { return description }
        return String(repeating: "0", count: Self.digits - description.count) + description
    }

    public func highOrderDigit() -> Int {
        rawValue / 100
    }

    public func lowOrderValue() -> Int {
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
