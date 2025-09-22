public enum LMCConstants: Sendable {
    public static let mailboxCount: Int = 100
    public static let decimalBase: Int = 1_000
    public static let wordRange: ClosedRange<Int> = 0...(decimalBase - 1)
    public static let signedWordRange: ClosedRange<Int> = -500...499
}
