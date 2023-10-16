import XCTest
@testable import CoreLittleManComputer

final class CoreLittleManComputerTests: XCTestCase {
    
    func createTestProgram() -> Program {
        let registers = [506, 107, 902, 108, 902, 000, 001, 010, 003, 000,
        000, 000, 000, 000, 000, 000, 000, 000, 000, 000,
        000, 000, 000, 000, 000, 000, 000, 000, 000, 000,
        000, 000, 000, 000, 000, 000, 000, 000, 000, 000,
        000, 000, 000, 000, 000, 000, 000, 000, 000, 000,
        000, 000, 000, 000, 000, 000, 000, 000, 000, 000,
        000, 000, 000, 000, 000, 000, 000, 000, 000, 000,
        000, 000, 000, 000, 000, 000, 000, 000, 000, 000,
        000, 000, 000, 000, 000, 000, 000, 000, 000, 000,
        000, 000, 000, 000, 000, 000, 000, 000, 000, 000]
        
        return Program(registers: registers)
    }
    
    // MARK: Compiler Tests
    func testCompile() {
        do {
            let code = """
                       LDA ONE
                       ADD TEN
                       OUT
                       ADD THREE
                       OUT
                       HLT
                       ONE DAT 001
                       TEN DAT 010
                       THREE DAT 003
                       """
            let testProgram = createTestProgram()
            
            let compiler = Compiler()
            let program = try compiler.compile(code)
            
            XCTAssert(program.registers == testProgram.registers, "PROGRAM: \(program)")
        } catch let error {
            XCTAssert(false, "Error: \(error)")
        }
    }
    
    // MARK: Virtual Machine Tests
    func testVirtualMachineStep() {
        let program = createTestProgram()
        let vm = VirtualMachine(program: program)
        vm.step()
        XCTAssert(vm.program.counter == 1, "Program counter should have incremented to 1. \n program counter: \(vm.program.counter)")
    }
    
    func testVirtualMachineRun() async throws {
        let program = createTestProgram()
        let vm = VirtualMachine(program: program)
        var count = 0
        try await vm.run(speed: 0.1)
        let executedProgram = vm.program
        XCTAssertEqual(executedProgram.counter, 5, "Program Counter: \(executedProgram.counter)")
        XCTAssertEqual(executedProgram.printStatement, "Program Complete", "Print Statement: \(executedProgram.printStatement)")
        XCTAssertEqual(executedProgram.outbox, [11, 14], "Outbox: \(executedProgram.outbox)")
        XCTAssertEqual(executedProgram.accumulator, 14, "Accumulator: \(executedProgram.accumulator)")
        XCTAssertNil(executedProgram.inbox, "Inbox should be nil but is \(String(describing: executedProgram.inbox))")
    }
}
