import Foundation
import Testing
@testable import CoreLittleManComputer

@Suite("Codable")
struct CodableTests {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private let decoder = JSONDecoder()

    private func json(_ value: some Encodable) throws -> String {
        String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    private func roundTrip<Value: Codable>(_ value: Value) throws -> Value {
        try decoder.decode(Value.self, from: encoder.encode(value))
    }

    @Test func numericTypesEncodeAsPlainIntegers() throws {
        #expect(try json(Word(42)) == "42")
        #expect(try json(SignedWord(-3)) == "-3")
        #expect(try json(MailboxAddress(7)) == "7")
        #expect(try json([Word(1), 2]) == "[1,2]")
        #expect(try roundTrip(Word(999)) == 999)
        #expect(try roundTrip(SignedWord(-999)) == -999)
        #expect(try roundTrip(MailboxAddress(99)) == 99)
    }

    @Test func numericTypesRejectValuesOutsideTheirRanges() {
        #expect(throws: DecodingError.self) { try decoder.decode(Word.self, from: Data("1000".utf8)) }
        #expect(throws: DecodingError.self) { try decoder.decode(Word.self, from: Data("-1".utf8)) }
        #expect(throws: DecodingError.self) { try decoder.decode(SignedWord.self, from: Data("-1000".utf8)) }
        #expect(throws: DecodingError.self) { try decoder.decode(MailboxAddress.self, from: Data("100".utf8)) }
    }

    @Test func memoryEncodesAsOneHundredIntegers() throws {
        var memory = Memory()
        memory[3] = 123
        let integers = try decoder.decode([Int].self, from: encoder.encode(memory))
        #expect(integers.count == 100)
        #expect(integers[3] == 123)
        #expect(try roundTrip(memory) == memory)
    }

    @Test func memoryRejectsTheWrongShape() {
        let tooFew = "[1,2,3]"
        let tooMany = "[" + Array(repeating: "0", count: 101).joined(separator: ",") + "]"
        let invalidWord = "[" + (["1000"] + Array(repeating: "0", count: 99)).joined(separator: ",") + "]"
        for text in [tooFew, tooMany, invalidWord] {
            #expect(throws: DecodingError.self) { try decoder.decode(Memory.self, from: Data(text.utf8)) }
        }
    }

    @Test func programsRoundTrip() throws {
        let program = try Assembler().assemble(SamplePrograms.countdown.source)
        #expect(try roundTrip(program) == program)
        #expect(try roundTrip(Program.empty) == .empty)
    }

    @Test func machinesRoundTripInEveryStatus() throws {
        var machine = try Machine(program: Assembler().assemble(SamplePrograms.countdown.source), inbox: [2], overflowBehavior: .wrap)
        #expect(try roundTrip(machine) == machine)
        machine.run()
        #expect(machine.status == .halted)
        #expect(try roundTrip(machine) == machine)

        var waiting = try Machine(program: Assembler().assemble(SamplePrograms.echo.source))
        waiting.step()
        #expect(waiting.status == .awaitingInput)
        #expect(try roundTrip(waiting) == waiting)

        var faulted = try Machine(program: #require(Program(words: [400])))
        faulted.step()
        #expect(faulted.status == .faulted(.invalidInstruction(word: 400, address: 0)))
        #expect(try roundTrip(faulted) == faulted)
    }

    @Test func overflowBehaviorEncodesAsAName() throws {
        #expect(try json(OverflowBehavior.wrap) == "\"wrap\"")
        #expect(try json(OverflowBehavior.fault) == "\"fault\"")
    }

    @Test func instructionsCyclesAndFaultsRoundTrip() throws {
        for instruction in [Instruction.add(5), .branchIfPositive(99), .input, .halt] {
            #expect(try roundTrip(instruction) == instruction)
        }
        let cycle = Cycle(index: 3, address: 4, instruction: .store(9), accumulator: -1, programCounter: 5, storedWord: 999)
        #expect(try roundTrip(cycle) == cycle)
        let fault = MachineFault.accumulatorOverflow(value: 1_000, address: 2)
        #expect(try roundTrip(fault) == fault)
    }
}
