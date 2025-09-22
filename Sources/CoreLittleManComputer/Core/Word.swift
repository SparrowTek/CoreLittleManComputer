public struct Word: Equatable, Hashable, Sendable {
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
}
