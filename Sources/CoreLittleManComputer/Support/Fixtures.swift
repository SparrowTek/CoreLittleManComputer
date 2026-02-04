public enum Fixtures: Sendable {
    public static var emptyProgram: Program {
        Program(words: [])
    }

    /// INP, OUT, HLT — echoes one input to output
    public static let echoSource = """
        INP
        OUT
        HLT
        """

    /// Reads two inputs, adds them, and outputs the result
    public static let addTwoNumbersSource = """
        INP
        STA FIRST
        INP
        ADD FIRST
        OUT
        HLT
        FIRST DAT 0
        """

    /// Counts down from a given input to zero, outputting each value
    public static let countdownSource = """
        INP
        LOOP OUT
        SUB ONE
        BRP LOOP
        HLT
        ONE DAT 1
        """

    /// Multiplies two inputs using repeated addition.
    /// A classic LMC exercise.
    public static let multiplicationSource = """
        INP
        STA A
        INP
        STA B
        LOOP LDA RESULT
        ADD A
        STA RESULT
        LDA B
        SUB ONE
        STA B
        BRP LOOP
        LDA RESULT
        OUT
        HLT
        A DAT 0
        B DAT 0
        RESULT DAT 0
        ONE DAT 1
        """
}
