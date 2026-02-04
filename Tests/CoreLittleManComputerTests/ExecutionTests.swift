#if canImport(Testing)
import Testing
import Foundation
@testable import CoreLittleManComputer

@Suite("Execution Engine")
struct ExecutionTests {

    @Test func handles_input_output() throws {
        let source = """
        INP
        OUT
        HLT
        """

        let program = try Assembler().assemble(source)
        let engine = ExecutionEngine(program: program, initialState: ProgramState(inbox: [42]))

        try engine.step() // INP
        #expect(engine.state.accumulator.value == 42)
        #expect(engine.state.counter == MailboxAddress(1))

        try engine.step() // OUT
        #expect(engine.state.outbox == [42])
        #expect(engine.state.counter == MailboxAddress(2))

        try engine.step() // HLT
        #expect(engine.state.halted)

        #expect(throws: ExecutionError.halted) {
            try engine.step()
        }
    }

    @Test func stores_accumulator_into_memory() throws {
        let source = """
        LDA TEN
        STA RESULT
        HLT
        TEN DAT 5
        RESULT DAT 0
        """

        let program = try Assembler().assemble(source)
        let engine = ExecutionEngine(program: program)

        try engine.step() // LDA TEN
        #expect(engine.state.accumulator.value == 5)

        try engine.step() // STA RESULT
        let resultAddress = MailboxAddress(4)
        #expect(engine.state.word(at: resultAddress).rawValue == 5)

        try engine.step() // HLT
        #expect(engine.state.halted)
    }

    @Test func run_until_halt() throws {
        let source = """
        LDA VALUE
        OUT
        HLT
        VALUE DAT 7
        """

        let program = try Assembler().assemble(source)
        let engine = ExecutionEngine(program: program)

        try engine.runUntilHalt()
        #expect(engine.state.halted)
        #expect(engine.state.outbox == [7])
    }

    @Test func breakpoint_stops_step() throws {
        let source = """
        LDA ONE
        ADD ONE
        HLT
        ONE DAT 1
        """

        let program = try Assembler().assemble(source)
        let engine = ExecutionEngine(program: program)
        engine.addBreakpoint(MailboxAddress(1))

        #expect(throws: ExecutionError.breakpointHit(MailboxAddress(1))) {
            try engine.step()
        }
    }

    @Test func async_run_stops_on_breakpoint() async throws {
        let source = """
        LDA ONE
        ADD ONE
        OUT
        BRA END
        ONE DAT 1
        END HLT
        """

        let program = try Assembler().assemble(source)
        let engine = ExecutionEngine(program: program)
        engine.addBreakpoint(MailboxAddress(3))

        do {
            try await engine.run(schedule: .unlimited)
            Issue.record("Expected breakpoint during async run")
        } catch ExecutionError.breakpointHit(let address) {
            #expect(address == MailboxAddress(3))
        }
    }

    @Test func branch_loop() throws {
        let source = """
        LOOP LDA COUNT
        OUT
        SUB ONE
        STA COUNT
        BRP LOOP
        HLT
        COUNT DAT 2
        ONE DAT 1
        """

        let program = try Assembler().assemble(source)
        let engine = ExecutionEngine(program: program)

        try engine.runUntilHalt(maxCycles: 100)
        #expect(engine.state.outbox == [2, 1, 0])
        #expect(engine.state.halted)
    }

    @Test func wrap_policy_handles_overflow() throws {
        let source = """
        LDA VALUE
        ADD VALUE
        OUT
        HLT
        VALUE DAT 600
        """

        let program = try Assembler().assemble(source)
        let engine = ExecutionEngine(program: program, numericPolicy: .wrapModulo)

        try engine.runUntilHalt()
        #expect(engine.state.outbox.first == 200)
    }

    @Test func random_adds() throws {
        for lhs in -3...3 {
            for rhs in -3...3 {
                let source = """
                LDA A
                ADD B
                OUT
                HLT
                A DAT \(lhs)
                B DAT \(rhs)
                """
                let program = try ProgramTextCodec().assemble(source)
                let engine = ExecutionEngine(program: program)
                try engine.runUntilHalt()
                #expect(engine.state.outbox == [lhs + rhs])
            }
        }
    }

    @Test func reset_restores_initial_state() throws {
        let source = """
        INP
        OUT
        HLT
        """

        let program = try Assembler().assemble(source)
        let engine = ExecutionEngine(program: program, initialState: ProgramState(inbox: [10]))

        try engine.runUntilHalt()
        #expect(engine.state.halted)
        #expect(engine.state.outbox == [10])

        engine.reset(initialState: ProgramState(inbox: [20]))
        #expect(!engine.state.halted)
        #expect(engine.state.outbox.isEmpty)

        try engine.runUntilHalt()
        #expect(engine.state.outbox == [20])
    }

    @Test func awaiting_input_when_inbox_empty() throws {
        let source = """
        INP
        HLT
        """

        let program = try Assembler().assemble(source)
        let engine = ExecutionEngine(program: program)

        #expect(throws: ExecutionError.awaitingInput) {
            try engine.step()
        }
    }

    @Test func program_counter_overflow_throws() throws {
        // Place a non-halt instruction at address 99
        var words = Array(repeating: Word.zero, count: 100)
        words[99] = Word(902) // OUT at address 99

        let program = Program(words: words)
        var state = ProgramState()
        state.advanceCounter(to: MailboxAddress(99))
        let engine = ExecutionEngine(program: program, initialState: state)

        #expect(throws: ExecutionError.programCounterOverflow) {
            try engine.step()
        }
    }

    @Test func performance_smoke() throws {
        let source = """
        LOOP LDA COUNT
        SUB ONE
        STA COUNT
        BRP LOOP
        HLT
        COUNT DAT 200
        ONE DAT 1
        """

        let program = try ProgramTextCodec().assemble(source)
        let engine = ExecutionEngine(program: program)

        let start = Date()
        try engine.runUntilHalt(maxCycles: 10_000)
        let elapsed = Date().timeIntervalSince(start)

        #expect(engine.state.halted)
        #expect(engine.state.cycles <= 10_000)
        #expect(elapsed < 1.0)
    }

    @Test func fixture_countdown_program() throws {
        let program = try ProgramTextCodec().assemble(Fixtures.countdownSource)
        let engine = ExecutionEngine(program: program, initialState: ProgramState(inbox: [3]))
        try engine.runUntilHalt(maxCycles: 1000)
        #expect(engine.state.outbox == [3, 2, 1, 0])
    }

    @Test func fixture_add_two_numbers() throws {
        let program = try ProgramTextCodec().assemble(Fixtures.addTwoNumbersSource)
        let engine = ExecutionEngine(program: program, initialState: ProgramState(inbox: [15, 27]))
        try engine.runUntilHalt()
        #expect(engine.state.outbox == [42])
    }

    @Test func error_descriptions_are_human_readable() {
        #expect(ExecutionError.halted.description.contains("halted"))
        #expect(ExecutionError.programCounterOverflow.description.contains("counter"))
        #expect(ExecutionError.awaitingInput.description.contains("input"))
    }
}
#endif
