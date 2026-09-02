/// A ready-to-run example together with the inputs it expects and the
/// outputs it produces, for help screens, demos and tests.
public struct SampleProgram: Hashable, Sendable, Identifiable {
    public var id: String { title }

    /// A short name, such as `"Countdown"`.
    public let title: String

    /// One sentence on what the program does.
    public let summary: String

    /// The assembly source.
    public let source: String

    /// Cards to place in the in-basket before running.
    public let inputs: [Word]

    /// What the out-basket holds after the program halts.
    public let expectedOutputs: [SignedWord]

    public init(title: String, summary: String, source: String, inputs: [Word], expectedOutputs: [SignedWord]) {
        self.title = title
        self.summary = summary
        self.source = source
        self.inputs = inputs
        self.expectedOutputs = expectedOutputs
    }
}

/// Classic Little Man Computer programs, including the examples from the
/// Wikipedia article.
public enum SamplePrograms {
    /// Reads one value and writes it straight back out.
    public static let echo = SampleProgram(
        title: "Echo",
        summary: "Reads one value and writes it back out.",
        source: """
        INP
        OUT
        HLT
        """,
        inputs: [7],
        expectedOutputs: [7]
    )

    /// Reads two values and outputs their sum.
    public static let addTwoNumbers = SampleProgram(
        title: "Add Two Numbers",
        summary: "Reads two values and outputs their sum.",
        source: """
              INP
              STA FIRST
              INP
              ADD FIRST
              OUT
              HLT
        FIRST DAT
        """,
        inputs: [15, 27],
        expectedOutputs: [42]
    )

    /// The Wikipedia example: reads two values and outputs the first minus the second.
    public static let subtractTwoNumbers = SampleProgram(
        title: "Subtract Two Numbers",
        summary: "Reads two values and outputs the first minus the second.",
        source: """
               INP
               STA FIRST
               INP
               STA SECOND
               LDA FIRST
               SUB SECOND
               OUT
               HLT
        FIRST  DAT
        SECOND DAT
        """,
        inputs: [8, 5],
        expectedOutputs: [3]
    )

    /// The Wikipedia example: counts down from the input to zero.
    public static let countdown = SampleProgram(
        title: "Countdown",
        summary: "Counts down from the input to zero, outputting every value.",
        source: """
             INP
             OUT      // Initialize output
        LOOP BRZ QUIT // If the accumulator value is 0, jump to QUIT
             SUB ONE  // Subtract the value stored at address ONE from the accumulator
             OUT
             BRA LOOP // Jump (unconditionally) to LOOP
        QUIT HLT
        ONE  DAT 1    // Store the value 1 in this mailbox and label it ONE
        """,
        inputs: [3],
        expectedOutputs: [3, 2, 1, 0]
    )

    /// Multiplies two values by repeated addition.
    public static let multiply = SampleProgram(
        title: "Multiply",
        summary: "Multiplies two values by repeated addition.",
        source: """
               INP
               STA A
               INP
               STA B
        LOOP   LDA B
               BRZ DONE
               SUB ONE
               STA B
               LDA RESULT
               ADD A
               STA RESULT
               BRA LOOP
        DONE   LDA RESULT
               OUT
               HLT
        A      DAT
        B      DAT
        RESULT DAT
        ONE    DAT 1
        """,
        inputs: [3, 4],
        expectedOutputs: [12]
    )

    /// Reads two values and outputs the larger one.
    public static let largerOfTwo = SampleProgram(
        title: "Larger of Two",
        summary: "Reads two values and outputs the larger one.",
        source: """
                  INP
                  STA FIRST
                  INP
                  STA SECOND
                  SUB FIRST
                  BRP SECONDWINS
                  LDA FIRST
                  OUT
                  HLT
        SECONDWINS LDA SECOND
                  OUT
                  HLT
        FIRST     DAT
        SECOND    DAT
        """,
        inputs: [5, 9],
        expectedOutputs: [9]
    )

    /// Every sample, in teaching order.
    public static let all: [SampleProgram] = [
        echo,
        addTwoNumbers,
        subtractTwoNumbers,
        countdown,
        multiply,
        largerOfTwo,
    ]
}
