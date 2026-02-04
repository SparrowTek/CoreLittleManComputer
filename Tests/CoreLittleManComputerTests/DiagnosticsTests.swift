#if canImport(Testing)
import Testing
@testable import CoreLittleManComputer

@Suite("Diagnostics")
struct DiagnosticsTests {

    @Test func trace_formatter_single_line() throws {
        let instruction = try Instruction(opcode: .add, operand: .address(MailboxAddress(5)))
        let entry = ProgramState.TraceEntry(cycle: 1,
                                            counter: MailboxAddress(2),
                                            instruction: instruction,
                                            accumulator: Accumulator(7))
        let formatter = TraceFormatter()
        let output = formatter.render([entry])
        #expect(output.contains("cycle\tcounter\topcode\taccumulator"))
        #expect(output.contains("1\t2\tADD\t7"))
    }

    @Test func trace_formatter_multi_line() throws {
        let instruction = try Instruction(opcode: .add, operand: .address(MailboxAddress(5)))
        let entry = ProgramState.TraceEntry(cycle: 1,
                                            counter: MailboxAddress(2),
                                            instruction: instruction,
                                            accumulator: Accumulator(7))
        let multi = TraceFormatter(style: .multiLine, includeHeader: false).render([entry])
        #expect(multi.contains("Cycle: 1"))
        #expect(multi.contains("Instruction: ADD"))
    }

    @Test func state_snapshot_formatter() {
        var state = ProgramState()
        state.emitOutput(3)
        let formatter = StateSnapshotFormatter()
        let summary = formatter.render(state)
        #expect(summary.contains("Outbox: [3]"))
    }

    @Test func trace_records_entries() throws {
        var state = ProgramState()
        let instruction = try Instruction(opcode: .halt)
        state.record(instruction: instruction)
        #expect(state.lastInstruction == instruction)
        #expect(state.trace.count == 1)
        #expect(state.trace.first?.instruction == instruction)

        state.emitOutput(3)
        state.emitOutput(7)
        #expect(state.outbox == [3, 7])
        state.clearOutputs()
        #expect(state.outbox.isEmpty)
    }
}
#endif
