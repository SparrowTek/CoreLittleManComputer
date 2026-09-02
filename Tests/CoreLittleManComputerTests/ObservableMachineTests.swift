#if canImport(Observation)
import Testing
@testable import CoreLittleManComputer

@MainActor
@Suite("ObservableMachine")
struct ObservableMachineTests {
    private func program(_ source: String) throws -> Program {
        try Assembler().assemble(source)
    }

    /// Waits for the observation task to deliver an event, up to two seconds.
    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<2_000 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(1))
        }
        Issue.record("Condition was not met in time")
    }

    /// Starts observing and returns once the mirror is receiving events.
    private func observe(_ observable: ObservableMachine) async -> Task<Void, Never> {
        let observation = Task { await observable.observe() }
        await waitUntil { observable.isObserving }
        return observation
    }

    @Test func mirrorsTheInitialMachine() throws {
        let program = try program(SamplePrograms.echo.source)
        let observable = ObservableMachine(program: program, inbox: [3])
        #expect(observable.machine == Machine(program: program, inbox: [3]))
        #expect(!observable.isRunning)
        #expect(observable.lastCycle == nil)
        #expect(observable.lastChange == nil)
        #expect(observable.lastRunOutcome == nil)
        #expect(!observable.isObserving)
    }

    @Test func reportsWhenItIsObserving() async throws {
        let observable = try ObservableMachine(program: program("HLT"))
        let observation = await observe(observable)
        #expect(observable.isObserving)
        observation.cancel()
        await waitUntil { !observable.isObserving }
    }

    @Test func reflectsStepsWhileObserving() async throws {
        let observable = try ObservableMachine(program: program(SamplePrograms.echo.source), inbox: [3])
        let observation = await observe(observable)
        defer { observation.cancel() }

        await observable.step()
        await waitUntil { observable.machine.cycleCount == 1 }

        #expect(observable.machine.accumulator == 3)
        #expect(observable.lastCycle?.instruction == .input)
        if let cycle = observable.lastCycle {
            #expect(observable.lastChange == .cycle(cycle))
        }
    }

    @Test func reflectsRunsAndTheirOutcome() async throws {
        let observable = try ObservableMachine(program: program(SamplePrograms.countdown.source), inbox: [2])
        let observation = await observe(observable)
        defer { observation.cancel() }

        let outcome = await observable.run()
        #expect(outcome == .halted)
        await waitUntil { observable.lastRunOutcome == .halted }

        #expect(observable.machine.outbox == [2, 1, 0])
        #expect(observable.machine.status == .halted)
        #expect(!observable.isRunning)
    }

    @Test func clearsTheLastCycleOnReset() async throws {
        let observable = try ObservableMachine(program: program(SamplePrograms.echo.source), inbox: [3])
        let observation = await observe(observable)
        defer { observation.cancel() }

        await observable.step()
        await waitUntil { observable.lastCycle != nil }
        await observable.reset(inbox: [4])
        await waitUntil { observable.lastChange == .reset }

        #expect(observable.lastCycle == nil)
        #expect(observable.machine.inbox == [4])
        #expect(observable.machine.cycleCount == 0)
    }

    @Test func forwardsInputWritesAndLoads() async throws {
        let observable = try ObservableMachine(program: program(SamplePrograms.echo.source))
        let observation = await observe(observable)
        defer { observation.cancel() }

        await observable.provideInput(6)
        await waitUntil { observable.machine.inbox == [6] }
        #expect(observable.lastChange == .inputProvided(6))

        await observable.write(42, at: 9)
        await waitUntil { observable.machine.memory[9] == 42 }
        #expect(observable.lastChange == .edited)

        let replacement = try program("HLT")
        await observable.load(replacement)
        await waitUntil { observable.lastChange == .programLoaded }
        #expect(observable.machine == Machine(program: replacement))
    }

    @Test func mirrorsAnExistingEngine() async throws {
        let engine = try ExecutionEngine(program: program(SamplePrograms.echo.source), inbox: [1])
        await engine.step()
        let observable = await ObservableMachine(engine: engine)
        #expect(observable.machine.cycleCount == 1)
        #expect(observable.engine === engine)
    }
}
#endif
