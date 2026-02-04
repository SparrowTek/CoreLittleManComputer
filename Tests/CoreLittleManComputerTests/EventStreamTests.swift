#if canImport(Testing)
import Testing
@testable import CoreLittleManComputer

@Suite("Event Streaming")
struct EventStreamTests {

    @Test func event_stream_publishes_events() async throws {
        let source = """
        INP
        OUT
        HLT
        """

        let program = try Assembler().assemble(source)
        let engine = ExecutionEngine(program: program, initialState: ProgramState(inbox: [9]))

        let eventTask = Task {
            try engine.step()
            try engine.step()
        }

        var iterator = engine.subscribe().makeAsyncIterator()
        var seenInstructionDecoded = false
        var seenOutput = false

        while let event = await iterator.next() {
            switch event {
            case .instructionDecoded(let instruction):
                if instruction.opcode == .output {
                    seenInstructionDecoded = true
                }
            case .outputProduced(let value):
                seenOutput = value == 9
            case .cycleCompleted:
                if seenInstructionDecoded && seenOutput {
                    break
                }
            default:
                break
            }
            if seenInstructionDecoded && seenOutput {
                break
            }
        }

        #expect(seenInstructionDecoded)
        #expect(seenOutput)
        try await eventTask.value
    }

    @Test func state_stream_emits_states() async throws {
        let source = """
        LDA VALUE
        OUT
        HLT
        VALUE DAT 4
        """

        let program = try Assembler().assemble(source)
        let engine = ExecutionEngine(program: program)

        let stream = engine.stateStream()
        var iterator = stream.makeAsyncIterator()

        let runTask = Task {
            try engine.runUntilHalt()
        }

        var observedOutboxes: [[Int]] = []
        while let state = await iterator.next() {
            observedOutboxes.append(state.outbox)
        }

        _ = try await runTask.value

        #expect(observedOutboxes.contains { $0 == [4] })
        #expect(engine.state.halted)
    }

    @Test func multiple_subscribers_receive_events() async throws {
        let source = """
        INP
        OUT
        HLT
        """

        let program = try Assembler().assemble(source)
        let engine = ExecutionEngine(program: program, initialState: ProgramState(inbox: [7]))

        let stream1 = engine.subscribe()
        let stream2 = engine.subscribe()

        // Collect events from both streams concurrently
        var count1 = 0
        var count2 = 0

        let collectTask1 = Task {
            var c = 0
            for await event in stream1 {
                c += 1
                if case .halted = event { break }
            }
            return c
        }

        let collectTask2 = Task {
            var c = 0
            for await event in stream2 {
                c += 1
                if case .halted = event { break }
            }
            return c
        }

        try engine.runUntilHalt()

        count1 = await collectTask1.value
        count2 = await collectTask2.value

        // Both subscribers should have received events
        #expect(count1 > 0)
        #expect(count2 > 0)
        #expect(count1 == count2)
    }
}
#endif
