public enum NumericError: Error, Sendable, Equatable {
    case overflow(value: Int)
}
