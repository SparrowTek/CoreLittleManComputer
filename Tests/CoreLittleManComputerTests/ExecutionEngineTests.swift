import Testing
@testable import CoreLittleManComputer

@Suite("ExecutionEngine")
struct ExecutionEngineTests {
    private func program(_ source: String) throws -> Program {
        try Assembler().assemble(source)
    }

    /// Collects events up to and including the first `.runFinished`.
    private func collectRun(_ events: AsyncStream<ExecutionEvent>) async -> [ExecutionEvent] {
        var collected: [ExecutionEvent] = []
        for await event in events {
            collected.append(event)
            if case .runFinished = event { break }
        }
        return collected
    }

    private func awaitRunStart(_ events: AsyncStream<ExecutionEvent>) async {
        for await event in events {
            if case .runStarted = event { return }
        }
    }

    private func cycles(in events: [ExecutionEvent]) -> [Cycle] {
        events.compactMap { event in
            if case .machineChanged(_, cause: .cycle(let cycle)) = event { cycle } else { nil }
        }
    }

    // MARK: Stepping and running

    @Test func stepsOneInstructionAndRecordsIt() async throws {
        let engine = try ExecutionEngine(program: program(SamplePrograms.echo.source), inbox: [5])
        let outcome = await engine.step()
        let machine = await engine.machine
        let trace = await engine.trace
        #expect(machine.accumulator == 5)
        #expect(machine.programCounter == 1)
        #expect(machine.inbox.isEmpty)
        guard case .executed(let cycle) = outcome else {
            Issue.record("Expected an executed cycle, got \(outcome)")
            return
        }
        #expect(trace == [cycle])
        #expect(cycle.input == 5)
    }

    @Test func runsToHaltAndPublishesEveryStep() async throws {
        let program = try program(SamplePrograms.countdown.source)
        let engine = ExecutionEngine(program: program, inbox: [2])
        let events = await engine.events()

        let outcome = await engine.run()
        let machine = await engine.machine
        let isRunning = await engine.isRunning
        #expect(outcome == .halted)
        #expect(machine.outbox == [2, 1, 0])
        #expect(machine.status == .halted)
        #expect(!isRunning)

        let collected = await collectRun(events)
        #expect(collected.first == .machineChanged(Machine(program: program, inbox: [2]), cause: .snapshot))
        #expect(collected.dropFirst().first == .runStarted)
        #expect(collected.last == .runFinished(.halted))
        #expect(collected.dropLast().last?.machine == machine)

        let cycles = cycles(in: collected)
        #expect(cycles.count == machine.cycleCount)
        #expect(cycles.map(\.index) == Array(0..<cycles.count))
        #expect(cycles.compactMap(\.output) == [2, 1, 0])
    }

    @Test func waitsForInputAndResumes() async throws {
        let engine = try ExecutionEngine(program: program(SamplePrograms.echo.source))
        let events = await engine.events()
        let first = await engine.run()
        #expect(first == .awaitingInput)

        await engine.provideInput(4)
        let second = await engine.run()
        let machine = await engine.machine
        #expect(second == .halted)
        #expect(machine.outbox == [4])

        let collected = await collectRun(events)
        #expect(collected.contains(.runFinished(.awaitingInput)))
        #expect(collected.contains { if case .machineChanged(_, cause: .awaitingInput) = $0 { true } else { false } })
    }

    @Test func stopsAtTheCycleLimit() async throws {
        let engine = try ExecutionEngine(program: program("LOOP BRA LOOP"))
        let outcome = await engine.run(maxCycles: 5)
        let count = await engine.machine.cycleCount
        #expect(outcome == .cycleLimitReached)
        #expect(count == 5)
    }

    @Test func reportsWhyAStoppedMachineCannotRun() async throws {
        let halted = try ExecutionEngine(program: program("HLT"))
        _ = await halted.run()
        let again = await halted.run()
        #expect(again == .halted)

        let invalid = try ExecutionEngine(program: #require(Program(words: [400])))
        let fault = MachineFault.invalidInstruction(word: 400, address: 0)
        let first = await invalid.run()
        let second = await invalid.run()
        let step = await invalid.step()
        #expect(first == .faulted(fault))
        #expect(second == .faulted(fault))
        #expect(step == .notRunning)
    }

    // MARK: Breakpoints

    @Test func stopsBeforeABreakpointAndResumesThroughIt() async throws {
        let engine = try ExecutionEngine(program: program("INP\nOUT\nOUT\nHLT"), inbox: [1])
        await engine.addBreakpoint(1)

        let first = await engine.run()
        var machine = await engine.machine
        #expect(first == .breakpoint(1))
        #expect(machine.programCounter == 1)
        #expect(machine.outbox.isEmpty)

        let second = await engine.run()
        machine = await engine.machine
        #expect(second == .halted)
        #expect(machine.outbox == [1, 1])
    }

    @Test func aBreakpointAtTheStartDoesNotBlockTheFirstRun() async throws {
        let engine = try ExecutionEngine(program: program("INP\nOUT\nHLT"), inbox: [1])
        await engine.addBreakpoint(0)
        let outcome = await engine.run()
        #expect(outcome == .halted)
    }

    @Test func stepIgnoresBreakpoints() async throws {
        let engine = try ExecutionEngine(program: program("INP\nOUT\nHLT"), inbox: [1])
        await engine.addBreakpoint(0)
        await engine.addBreakpoint(1)
        let outcome = await engine.step()
        guard case .executed = outcome else {
            Issue.record("Expected an executed cycle, got \(outcome)")
            return
        }
    }

    @Test func managesBreakpoints() async throws {
        let engine = try ExecutionEngine(program: program("HLT"))
        await engine.addBreakpoint(3)
        await engine.addBreakpoint(4)
        #expect(await engine.breakpoints == [3, 4])

        await engine.removeBreakpoint(3)
        #expect(await engine.breakpoints == [4])

        #expect(await engine.toggleBreakpoint(4) == false)
        #expect(await engine.toggleBreakpoint(7) == true)
        #expect(await engine.breakpoints == [7])

        await engine.setBreakpoints([1, 2])
        #expect(await engine.breakpoints == [1, 2])

        await engine.clearBreakpoints()
        #expect(await engine.breakpoints.isEmpty)
    }

    // MARK: Pausing

    @Test func pausesAPacedRun() async throws {
        let engine = try ExecutionEngine(program: program("LOOP BRA LOOP"))
        let events = await engine.events()
        async let outcome = engine.run(speed: .cycleDuration(.milliseconds(1)))
        await awaitRunStart(events)
        await engine.pause()
        let result = await outcome
        let isRunning = await engine.isRunning
        #expect(result == .paused)
        #expect(!isRunning)
    }

    @Test func pausesARunAtMaximumSpeed() async throws {
        let engine = try ExecutionEngine(program: program("LOOP BRA LOOP"))
        let events = await engine.events()
        async let outcome = engine.run(speed: .maximum)
        await awaitRunStart(events)
        await engine.pause()
        let result = await outcome
        #expect(result == .paused)
    }

    @Test func cancellingTheTaskPausesTheRun() async throws {
        let engine = try ExecutionEngine(program: program("LOOP BRA LOOP"))
        let events = await engine.events()
        let task = Task { await engine.run(speed: .cycleDuration(.milliseconds(1))) }
        await awaitRunStart(events)
        task.cancel()
        let result = await task.value
        #expect(result == .paused)
    }

    @Test func refusesASecondConcurrentRun() async throws {
        let engine = try ExecutionEngine(program: program("LOOP BRA LOOP"))
        let events = await engine.events()
        async let first = engine.run(speed: .cycleDuration(.milliseconds(1)))
        await awaitRunStart(events)
        let second = await engine.run()
        #expect(second == .alreadyRunning)
        await engine.pause()
        let result = await first
        #expect(result == .paused)
    }

    @Test func resetDuringARunPausesIt() async throws {
        let engine = try ExecutionEngine(program: program("LOOP BRA LOOP"))
        let events = await engine.events()
        async let outcome = engine.run(speed: .cycleDuration(.milliseconds(1)))
        await awaitRunStart(events)
        await engine.reset()
        let result = await outcome
        let machine = await engine.machine
        #expect(result == .paused)
        #expect(machine.cycleCount == 0)
    }

    // MARK: Loading, resetting and editing

    @Test func resetRestoresTheProgram() async throws {
        let program = try program("INP\nSTA 5\nOUT\nHLT")
        let engine = ExecutionEngine(program: program, inbox: [1])
        _ = await engine.run()
        #expect(await engine.machine.memory[5] == 1)

        let events = await engine.events()
        await engine.reset(inbox: [2])
        let machine = await engine.machine
        let trace = await engine.trace
        #expect(machine == Machine(program: program, inbox: [2]))
        #expect(trace.isEmpty)

        let outcome = await engine.run()
        #expect(outcome == .halted)
        #expect(await engine.machine.outbox == [2])

        let collected = await collectRun(events)
        #expect(collected.contains(.machineChanged(Machine(program: program, inbox: [2]), cause: .reset)))
    }

    @Test func loadsADifferentProgram() async throws {
        let engine = try ExecutionEngine(program: program("HLT"))
        let events = await engine.events()
        let replacement = try program(SamplePrograms.echo.source)
        await engine.load(replacement, inbox: [9])

        #expect(await engine.program == replacement)
        #expect(await engine.machine == Machine(program: replacement, inbox: [9]))

        let outcome = await engine.run()
        #expect(outcome == .halted)
        #expect(await engine.machine.outbox == [9])

        let collected = await collectRun(events)
        #expect(collected.contains(.machineChanged(Machine(program: replacement, inbox: [9]), cause: .programLoaded)))
    }

    @Test func editsPublishTheNewState() async throws {
        let engine = try ExecutionEngine(program: program("HLT"))
        let events = await engine.events()
        await engine.write(902, at: 0)
        await engine.edit { $0.accumulator = 5 }
        await engine.setOverflowBehavior(.wrap)
        let machine = await engine.machine
        #expect(machine.memory[0] == 902)
        #expect(machine.accumulator == 5)
        #expect(machine.overflowBehavior == .wrap)

        _ = await engine.run()
        let collected = await collectRun(events)
        let edits = collected.filter { if case .machineChanged(_, cause: .edited) = $0 { true } else { false } }
        #expect(edits.count == 3)
        #expect(edits.last?.machine == machine)
        #expect(await engine.machine.outbox == [5])
    }

    // MARK: Trace and events

    @Test func keepsOnlyTheMostRecentCycles() async throws {
        let engine = try ExecutionEngine(program: program("LOOP BRA LOOP"), traceLimit: 3)
        _ = await engine.run(maxCycles: 5)
        #expect(await engine.trace.map(\.index) == [2, 3, 4])
        await engine.clearTrace()
        #expect(await engine.trace.isEmpty)
    }

    @Test func everySubscriberSeesEveryEvent() async throws {
        let engine = try ExecutionEngine(program: program(SamplePrograms.countdown.source), inbox: [1])
        let first = await engine.events()
        let second = await engine.events()
        _ = await engine.run()
        let firstEvents = await collectRun(first)
        let secondEvents = await collectRun(second)
        #expect(firstEvents == secondEvents)
        #expect(cycles(in: firstEvents).count == 8)
    }

    @Test func aDroppedSubscriberDoesNotDisturbOthers() async throws {
        let engine = try ExecutionEngine(program: program(SamplePrograms.countdown.source), inbox: [1])
        do {
            let dropped = await engine.events()
            _ = dropped
        }
        let kept = await engine.events()
        _ = await engine.run()
        let events = await collectRun(kept)
        #expect(events.last == .runFinished(.halted))
    }

    // MARK: Pacing

    @Test func pacedRunsWaitBetweenInstructions() async throws {
        let engine = try ExecutionEngine(program: program("LOOP BRA LOOP"))
        let clock = ContinuousClock()
        var outcome: RunOutcome?
        let elapsed = await clock.measure {
            outcome = await engine.run(speed: .cycleDuration(.milliseconds(2)), maxCycles: 3, clock: clock)
        }
        #expect(outcome == .cycleLimitReached)
        #expect(elapsed >= .milliseconds(6))
    }

    @Test func hertzConvertsToACycleDuration() {
        #expect(ExecutionSpeed.hertz(4) == .cycleDuration(.milliseconds(250)))
        #expect(ExecutionSpeed.hertz(4).cycleDuration == .milliseconds(250))
        #expect(ExecutionSpeed.hertz(0) == .maximum)
        #expect(ExecutionSpeed.hertz(-1) == .maximum)
        #expect(ExecutionSpeed.hertz(.infinity) == .maximum)
        #expect(ExecutionSpeed.hertz(.nan) == .maximum)
        #expect(ExecutionSpeed.maximum.cycleDuration == nil)
    }
}
