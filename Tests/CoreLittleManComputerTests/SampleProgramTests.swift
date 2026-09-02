import Testing
@testable import CoreLittleManComputer

@Suite("Sample programs")
struct SampleProgramTests {
    private func outputs(of sample: SampleProgram, inputs: [Word]) throws -> [SignedWord] {
        var machine = try Machine(program: Assembler().assemble(sample.source), inbox: inputs)
        #expect(machine.run() == .halted)
        return machine.outbox
    }

    @Test(arguments: SamplePrograms.all)
    func producesItsDocumentedOutputs(sample: SampleProgram) throws {
        #expect(try outputs(of: sample, inputs: sample.inputs) == sample.expectedOutputs)
    }

    @Test func listsEverySampleOnce() {
        let titles = SamplePrograms.all.map(\.title)
        #expect(titles.count == 6)
        #expect(Set(titles).count == titles.count)
        #expect(SamplePrograms.all.map(\.id) == titles)
    }

    @Test func subtractionGoesNegative() throws {
        #expect(try outputs(of: SamplePrograms.subtractTwoNumbers, inputs: [5, 8]) == [-3])
    }

    @Test func countdownFromZeroOutputsZero() throws {
        #expect(try outputs(of: SamplePrograms.countdown, inputs: [0]) == [0])
    }

    @Test func multiplicationHandlesZeroAndSquares() throws {
        #expect(try outputs(of: SamplePrograms.multiply, inputs: [0, 5]) == [0])
        #expect(try outputs(of: SamplePrograms.multiply, inputs: [5, 0]) == [0])
        #expect(try outputs(of: SamplePrograms.multiply, inputs: [12, 12]) == [144])
    }

    @Test func largerOfTwoHandlesEitherOrderAndTies() throws {
        #expect(try outputs(of: SamplePrograms.largerOfTwo, inputs: [9, 5]) == [9])
        #expect(try outputs(of: SamplePrograms.largerOfTwo, inputs: [4, 4]) == [4])
    }

    @Test func additionBeyondTheAccumulatorFaults() throws {
        var machine = try Machine(program: Assembler().assemble(SamplePrograms.addTwoNumbers.source), inbox: [999, 1])
        #expect(machine.run() == .faulted(.accumulatorOverflow(value: 1_000, address: 3)))
    }
}
