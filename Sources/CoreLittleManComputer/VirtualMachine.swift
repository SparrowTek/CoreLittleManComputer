
public typealias Mailbox = Int

public enum VirtualMachineError: Error {
    case mailboxOutOfBounds
    case inputNeeded
    case generic
}

public class VirtualMachine {
    var program: Program
    var input: Int?
    
    init(program: Program) {
        self.program = program
    }
    
    func step() {
        do {
            let register = program.registers[program.counter]
            let instruction = getInstruction(for: register)
            resetRegistersCurrentlyBeingEvaluated()
            try execute(instruction: instruction, for: &program)
            programShouldCompleteCheck(register: register)
            //        } catch let error as StateError {
            //            state.send(completion: .failure(error))
            //        } catch {
            //            state.send(completion: .failure(.generic))
            //        }
        } catch { }
    }
    
    func run(speed: Double) {
        
    }
    
    private func programShouldCompleteCheck(register: Register) {
        if opcode(for: register) == .halt {
//            state.send(completion: .finished)
            // TODO: end async stream
        }
    }
    
    private func execute(instruction: Instruction, for program: inout Program) throws {
        let opcode = instruction.opcode
        let mailbox = instruction.address
        guard mailbox >= 0 && mailbox <= 99 else { throw VirtualMachineError.mailboxOutOfBounds }
        
        
        switch opcode {
        case .add:
            add(mailbox: mailbox, for: &program)
        case .subtract:
            subtract(mailbox: mailbox, for: &program)
        case .store:
            store(mailbox: mailbox, for: &program)
        case .load:
            load(mailbox: mailbox, for: &program)
        case .branch:
            branch(mailbox: mailbox, for: &program)
        case .branchIfZero:
            branchIfZero(mailbox: mailbox, for: &program)
        case .branchIfPositive:
            branchIfPositive(mailbox: mailbox, for: &program)
        case .input:
            try input(for: &program)
        case .output:
            output(for: &program)
        case .halt:
            halt(for: &program)
        case .data:
            throw VirtualMachineError.generic
        }
    }
    
    private func resetRegistersCurrentlyBeingEvaluated() {
        program.registersCurrentlyBeingEvaluated = [ : ]
    }
    
    private func getInstruction(for register: Register) -> Instruction {
        let registerOpcode = opcode(for: register)
        
        switch registerOpcode {
        case .input, .output, .halt:
            return Instruction(opcode: registerOpcode, address: 0)
        default:
            let mailboxAddress = address(for: register)
            return Instruction(opcode: registerOpcode, address: mailboxAddress)
        }
    }
    
    private func address(for register: Register) -> Mailbox {
        let registerHundredsDigit = (register - (register % 100))
        return register - registerHundredsDigit
    }
    
    private func opcode(for register: Register) -> Opcode {
        let registerFirstDigit = (register - (register % 100)) / 100
        
        switch registerFirstDigit {
        case 1:
            return .add
        case 2:
            return .subtract
        case 3:
            return .store
        case 5:
            return .load
        case 6:
            return .branch
        case 7:
            return .branchIfZero
        case 8:
            return .branchIfPositive
        case 9:
            if register == 901 {
                return .input
            } else {
                return .output
            }
        default:
            return .halt
        }
    }
    
    private func add(mailbox: Mailbox, for program: inout Program) {
        let accumulator = program.accumulator
        let registerValue = program.registers[mailbox]
        
        program.registersCurrentlyBeingEvaluated[program.counter] = true
        program.accumulator += registerValue
        program.counter += 1
        program.printStatement = "Add \(accumulator) from the accumulator to the value in register \(mailbox) (\(registerValue))"
    }
    
    private func subtract(mailbox: Mailbox, for program: inout Program) {
        let accumulator = program.accumulator
        let registerValue = program.registers[mailbox]
        
        program.registersCurrentlyBeingEvaluated[program.counter] = true
        program.accumulator -= registerValue
        program.counter += 1
        program.printStatement = "Subtract \(registerValue) in register \(mailbox) from the accumulator value (\(accumulator))"
    }
    
    private func store(mailbox: Mailbox, for program: inout Program) {
        program.registersCurrentlyBeingEvaluated[program.counter] = true
        program.registersCurrentlyBeingEvaluated[mailbox] = true
        program.registers[mailbox] = program.accumulator
        program.counter += 1
        program.printStatement = "Store the accumulator value \(program.accumulator) in register \(mailbox)"
    }
    
    private func load(mailbox: Mailbox, for program: inout Program) {
        program.registersCurrentlyBeingEvaluated[program.counter] = true
        program.registersCurrentlyBeingEvaluated[mailbox] = true
        program.accumulator = program.registers[mailbox]
        program.counter += 1
        program.printStatement = "Load the value in register \(mailbox) (\(program.registers[mailbox])) into the accumulator"
    }
    
    private func branch(mailbox: Mailbox, for program: inout Program) {
        program.registersCurrentlyBeingEvaluated[program.counter] = true
        program.counter = mailbox
        program.printStatement = "Branch: change the program counter to the value in register \(mailbox)"
    }
    
    private func branchIfZero(mailbox: Mailbox, for program: inout Program) {
        program.registersCurrentlyBeingEvaluated[program.counter] = true
        if program.accumulator == 0 {
            program.counter = mailbox
            program.printStatement = "Branch if zero: Accumulator == 0 is true. Program counter sets to \(mailbox)"
        } else {
            program.counter += 1
            program.printStatement = "Branch if zero: The accumulator != 0. Do not branch; increment program counter"
        }
    }
    
    private func branchIfPositive(mailbox: Mailbox, for program: inout Program) {
        program.registersCurrentlyBeingEvaluated[program.counter] = true
        if program.accumulator >= 0 {
            program.counter = mailbox
            program.printStatement = "Branch if positive: Accumulator >= 0 is true. Program counter sets to \(mailbox)"
        } else {
            program.counter += 1
            program.printStatement = "Branch if positive: Accumulator is not possitive. Do not branch"
        }
    }
    
    private func input(for program: inout Program) throws {
        guard let inbox = program.inbox else { throw VirtualMachineError.inputNeeded }
        program.registersCurrentlyBeingEvaluated[program.counter] = true
        program.accumulator = inbox
        program.inbox = nil
        program.counter += 1
        program.printStatement = "Input"
    }
    
    private func output(for program: inout Program) {
        program.registersCurrentlyBeingEvaluated[program.counter] = true
        program.outbox.append(program.accumulator)
        program.counter += 1
        program.printStatement = "Output: output the value in the accumulator, \(program.accumulator) into the output box"
    }
    
    private func halt(for program: inout Program) {
        program.registersCurrentlyBeingEvaluated[program.counter] = true
        program.printStatement = "Program Complete"
    }
}
