import Testing
@testable import CoreLittleManComputer

@Suite("Machine")
struct MachineTests {
    private func machine(
        _ source: String,
        inbox: [Word] = [],
        overflow: OverflowBehavior = .fault
    ) throws -> Machine {
        try Machine(program: Assembler().assemble(source), inbox: inbox, overflowBehavior: overflow)
    }

    private func machine(words: [Word], inbox: [Word] = []) throws -> Machine {
        try Machine(program: #require(Program(words: words)), inbox: inbox)
    }

    @Test func startsAtRestAtMailboxZero() throws {
        let machine = try machine(SamplePrograms.echo.source)
        #expect(machine.programCounter == .zero)
        #expect(machine.accumulator == .zero)
        #expect(machine.status == .ready)
        #expect(machine.cycleCount == 0)
        #expect(machine.outbox.isEmpty)
        #expect(machine.canStep)
        #expect(machine.nextInstruction == .input)
        #expect(machine.overflowBehavior == .fault)
    }

    @Test func loadPlacesTheUnsignedWordInTheAccumulator() throws {
        var machine = try machine("LDA X\nHLT\nX DAT 999")
        machine.step()
        #expect(machine.accumulator == 999)
        #expect(!machine.accumulator.isNegative)
    }

    @Test func addRecordsTheCycle() throws {
        var machine = try machine("LDA A\nADD B\nHLT\nA DAT 5\nB DAT 3")
        machine.step()
        let outcome = machine.step()
        #expect(outcome == .executed(Cycle(
            index: 1,
            address: 1,
            instruction: .add(4),
            accumulator: 8,
            programCounter: 2
        )))
        #expect(machine.accumulator == 8)
        #expect(machine.cycleCount == 2)
        if case .executed(let cycle) = outcome {
            #expect(cycle.readAddress == 4)
            #expect(cycle.writtenAddress == nil)
        }
    }

    @Test func subtractProducesNegativeValues() throws {
        var machine = try machine("LDA A\nSUB B\nOUT\nHLT\nA DAT 5\nB DAT 8")
        machine.run()
        #expect(machine.accumulator == -3)
        #expect(machine.outbox == [-3])
    }

    @Test func additionOverflowFaultsByDefault() throws {
        var machine = try machine("LDA MAX\nADD ONE\nHLT\nMAX DAT 999\nONE DAT 1")
        machine.step()
        let outcome = machine.step()
        let fault = MachineFault.accumulatorOverflow(value: 1_000, address: 1)
        #expect(outcome == .faulted(fault))
        #expect(machine.status == .faulted(fault))
        #expect(machine.programCounter == 1)
        #expect(machine.accumulator == 999)
        #expect(machine.cycleCount == 1)
        #expect(!machine.canStep)
        #expect(machine.step() == .notRunning)
        #expect(machine.run() == .faulted(fault))
        #expect(fault.description.contains("1000"))
    }

    @Test func subtractionOverflowFaultsByDefault() throws {
        var machine = try machine("SUB BIG\nSUB ONE\nHLT\nBIG DAT 999\nONE DAT 1")
        machine.step()
        #expect(machine.accumulator == -999)
        #expect(machine.step() == .faulted(.accumulatorOverflow(value: -1_000, address: 1)))
    }

    @Test func wrappingKeepsSignAndLowDigits() throws {
        var overflow = try machine("LDA MAX\nADD ONE\nOUT\nADD BIG\nADD BIG\nOUT\nHLT\nMAX DAT 999\nONE DAT 1\nBIG DAT 600", overflow: .wrap)
        #expect(overflow.run() == .halted)
        #expect(overflow.outbox == [0, 200])

        var underflow = try machine("SUB BIG\nSUB BIG\nOUT\nHLT\nBIG DAT 600", overflow: .wrap)
        #expect(underflow.run() == .halted)
        #expect(underflow.outbox == [-200])
    }

    @Test func storeWritesNegativeValuesInTensComplement() throws {
        var machine = try machine("SUB ONE\nSTA X\nHLT\nONE DAT 1\nX DAT")
        machine.step()
        let outcome = machine.step()
        #expect(machine.memory[4] == 999)
        #expect(machine.accumulator == -1)
        if case .executed(let cycle) = outcome {
            #expect(cycle.storedWord == 999)
            #expect(cycle.writtenAddress == 4)
        } else {
            Issue.record("Expected an executed cycle, got \(outcome)")
        }
    }

    @Test func storeWritesPositiveValuesUnchanged() throws {
        var machine = try machine("LDA A\nSTA X\nHLT\nA DAT 42\nX DAT")
        machine.run()
        #expect(machine.memory[4] == 42)
    }

    @Test func branchAlwaysChangesTheProgramCounter() throws {
        var machine = try machine("BRA END\nHLT\nEND HLT")
        let outcome = machine.step()
        #expect(machine.programCounter == 2)
        if case .executed(let cycle) = outcome {
            #expect(cycle.branched)
            #expect(cycle.programCounter == 2)
        }
    }

    @Test func branchIfZeroOnlyBranchesOnZero() throws {
        var zero = try machine("BRZ END\nHLT\nEND HLT")
        zero.step()
        #expect(zero.programCounter == 2)

        var positive = try machine("LDA ONE\nBRZ END\nHLT\nEND HLT\nONE DAT 1")
        positive.step()
        let outcome = positive.step()
        #expect(positive.programCounter == 2)
        if case .executed(let cycle) = outcome {
            #expect(!cycle.branched)
        }

        var negative = try machine("SUB ONE\nBRZ END\nHLT\nEND HLT\nONE DAT 1")
        negative.step()
        negative.step()
        #expect(negative.programCounter == 2)
    }

    @Test func branchIfPositiveBranchesOnZeroAndPositive() throws {
        var zero = try machine("BRP END\nHLT\nEND HLT")
        zero.step()
        #expect(zero.programCounter == 2)

        var positive = try machine("LDA ONE\nBRP END\nHLT\nEND HLT\nONE DAT 1")
        positive.step()
        positive.step()
        #expect(positive.programCounter == 3)

        var negative = try machine("SUB ONE\nBRP END\nHLT\nEND HLT\nONE DAT 1")
        negative.step()
        negative.step()
        #expect(negative.programCounter == 2)
    }

    @Test func inputWaitsForAnEmptyInbox() throws {
        var machine = try machine(SamplePrograms.echo.source)
        #expect(machine.step() == .awaitingInput)
        #expect(machine.status == .awaitingInput)
        #expect(machine.programCounter == .zero)
        #expect(machine.cycleCount == 0)
        #expect(!machine.canStep)
        #expect(machine.step() == .awaitingInput)
        #expect(machine.run() == .awaitingInput)

        machine.provideInput(7)
        #expect(machine.status == .ready)
        #expect(machine.canStep)
        let outcome = machine.step()
        #expect(machine.accumulator == 7)
        #expect(machine.inbox.isEmpty)
        if case .executed(let cycle) = outcome {
            #expect(cycle.input == 7)
        }
    }

    @Test func inputResumesWhenTheInboxIsFilledDirectly() throws {
        var machine = try machine(SamplePrograms.echo.source)
        machine.step()
        machine.inbox.append(9)
        #expect(machine.canStep)
        #expect(machine.run() == .halted)
        #expect(machine.outbox == [9])
    }

    @Test func inputReadsCardsInOrder() throws {
        var machine = try machine("INP\nINP\nOUT\nHLT", inbox: [1, 2])
        machine.run()
        #expect(machine.outbox == [2])
    }

    @Test func outputCopiesTheAccumulator() throws {
        var machine = try machine("LDA A\nOUT\nOUT\nHLT\nA DAT 12")
        machine.run()
        #expect(machine.outbox == [12, 12])
        #expect(machine.accumulator == 12)
    }

    @Test func haltStopsWithTheCounterOnePastTheHalt() throws {
        var machine = try machine("INP\nHLT", inbox: [1])
        machine.step()
        let outcome = machine.step()
        #expect(outcome == .executed(Cycle(index: 1, address: 1, instruction: .halt, accumulator: 1, programCounter: 2)))
        #expect(machine.status == .halted)
        #expect(machine.status.hasStopped)
        #expect(machine.step() == .notRunning)
        #expect(machine.run() == .halted)
        #expect(machine.cycleCount == 2)
    }

    @Test func wordsBelowOneHundredHalt() throws {
        var machine = try machine(words: [42])
        #expect(machine.step() == .executed(Cycle(index: 0, address: 0, instruction: .halt, accumulator: 0, programCounter: 1)))
        #expect(machine.status == .halted)
    }

    @Test func blankMemoryHaltsImmediately() {
        var machine = Machine()
        #expect(machine.run() == .halted)
        #expect(machine.cycleCount == 1)
    }

    @Test(arguments: [400, 450, 499, 900, 903, 999])
    func invalidWordsFault(value: Int) throws {
        let word = Word(wrapping: value)
        var machine = try machine(words: [word])
        let fault = MachineFault.invalidInstruction(word: word, address: 0)
        #expect(machine.step() == .faulted(fault))
        #expect(machine.status == .faulted(fault))
        #expect(machine.programCounter == .zero)
        #expect(fault.description.contains(word.description))
    }

    @Test func programCounterWrapsFromNinetyNineToZero() throws {
        var machine = Machine()
        machine.memory[99] = 902
        machine.programCounter = 99
        machine.step()
        #expect(machine.programCounter == .zero)
        #expect(machine.outbox == [0])
    }

    @Test func runStopsAtTheCycleLimit() throws {
        var machine = try machine("LOOP BRA LOOP")
        #expect(machine.run(maxCycles: 10) == .cycleLimitReached)
        #expect(machine.cycleCount == 10)
        #expect(machine.status == .ready)
        #expect(machine.run(maxCycles: 0) == .cycleLimitReached)
    }

    @Test func runReportsHowItEnded() throws {
        var countdown = try machine(SamplePrograms.countdown.source, inbox: [2])
        #expect(countdown.run() == .halted)
        #expect(countdown.outbox == [2, 1, 0])

        var input = try machine(SamplePrograms.echo.source)
        #expect(input.run() == .awaitingInput)

        var invalid = try machine(words: [400])
        #expect(invalid.run() == .faulted(.invalidInstruction(word: 400, address: 0)))
    }

    @Test func identicalHistoriesProduceEqualMachines() throws {
        var first = try machine(SamplesForEquality.source, inbox: [3])
        var second = try machine(SamplesForEquality.source, inbox: [3])
        first.run()
        second.run()
        #expect(first == second)
        #expect(first.hashValue == second.hashValue)
        second.outbox.append(0)
        #expect(first != second)
    }

    private enum SamplesForEquality {
        static let source = SamplePrograms.countdown.source
    }
}
