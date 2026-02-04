public enum NumericError: Error, Sendable, Equatable, CustomStringConvertible {
    case overflow(value: Int)

    public var description: String {
        switch self {
        case .overflow(let value):
            return "Numeric overflow: \(value) is outside the valid range \(LMCConstants.signedWordRange)"
        }
    }
}
