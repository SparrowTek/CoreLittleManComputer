public enum ExecutionError: Error, Sendable, Equatable {
    case halted
    case awaitingInput
    case mailboxOutOfBounds(MailboxAddress)
    case invalidInstruction(Word)
    case numericError(NumericError)
}

public final class ExecutionEngine: @unchecked Sendable {
    public let program: Program
    public let numericPolicy: NumericPolicy
    private(set) public var state: ProgramState
    private let observer: ExecutionObserver

    public init(program: Program,
                initialState: ProgramState = ProgramState(),
                numericPolicy: NumericPolicy = .trapOnOverflow,
                observer: ExecutionObserver = NoOpObserver()) {
        self.program = program
        var workingState = initialState
        workingState.ensureMemoryInitialized(with: program.memoryImage)
        self.state = workingState
        self.numericPolicy = numericPolicy
        self.observer = observer
    }

    public func step() throws {
        guard !state.halted else {
            throw ExecutionError.halted
        }

        let counter = state.counter
        guard MailboxAddress.validRange.contains(counter.rawValue) else {
            throw ExecutionError.mailboxOutOfBounds(counter)
        }

        observer.handle(.cycleStarted(cycle: state.cycles, counter: counter))

        let word = state.word(at: counter)
        let decoded: InstructionWord.Decoded
        do {
            decoded = try InstructionWord(word).decode()
        } catch {
            state.setHalted()
            observer.handle(.error("Invalid instruction word \(word.rawValue)"))
            throw ExecutionError.invalidInstruction(word)
        }

        switch decoded {
        case .data:
            state.setHalted()
            observer.handle(.error("Encountered data at \(counter.rawValue)"))
            throw ExecutionError.invalidInstruction(word)
        case .instruction(let instruction):
            state.record(instruction: instruction)
            observer.handle(.instructionDecoded(instruction))
            try execute(instruction)
            state.incrementCycle()
        }
    }

    private func execute(_ instruction: Instruction) throws {
        switch instruction.opcode {
        case .add:
            try add(from: instruction)
        case .subtract:
            try subtract(from: instruction)
        case .store:
            try store(from: instruction)
        case .load:
            try load(from: instruction)
        case .branch:
            try branch(to: instruction)
        case .branchIfZero:
            try branchIfZero(to: instruction)
        case .branchIfPositive:
            try branchIfPositive(to: instruction)
        case .input:
            try input()
        case .output:
            output()
        case .halt:
            halt()
        case .data:
            throw ExecutionError.invalidInstruction(Word.zero)
        }
    }

    private func add(from instruction: Instruction) throws {
        let address = try operandAddress(from: instruction)
        let word = state.word(at: address)
        do {
            let result = try state.accumulator.adding(word: word, policy: numericPolicy)
            state.updateAccumulator(result)
        } catch let error as NumericError {
            state.setHalted()
            throw ExecutionError.numericError(error)
        }
        state.incrementCounter()
    }

    private func subtract(from instruction: Instruction) throws {
        let address = try operandAddress(from: instruction)
        let word = state.word(at: address)
        do {
            let result = try state.accumulator.subtracting(word: word, policy: numericPolicy)
            state.updateAccumulator(result)
        } catch let error as NumericError {
            state.setHalted()
            throw ExecutionError.numericError(error)
        }
        state.incrementCounter()
    }

    private func store(from instruction: Instruction) throws {
        let address = try operandAddress(from: instruction)
        try writeAccumulator(to: address)
        state.incrementCounter()
    }

    private func load(from instruction: Instruction) throws {
        let address = try operandAddress(from: instruction)
        let word = state.word(at: address)
        state.updateAccumulator(Accumulator(word.signedValue))
        state.incrementCounter()
    }

    private func branch(to instruction: Instruction) throws {
        let address = try operandAddress(from: instruction)
        state.advanceCounter(to: address)
    }

    private func branchIfZero(to instruction: Instruction) throws {
        if state.accumulator.value == 0 {
            try branch(to: instruction)
        } else {
            state.incrementCounter()
        }
    }

    private func branchIfPositive(to instruction: Instruction) throws {
        if state.accumulator.value >= 0 {
            try branch(to: instruction)
        } else {
            state.incrementCounter()
        }
    }

    private func input() throws {
        guard let value = state.dequeueInbox() else {
            throw ExecutionError.awaitingInput
        }
        do {
            let accumulator = try numericPolicy.accumulator(from: value)
            state.updateAccumulator(accumulator)
        } catch let error as NumericError {
            state.setHalted()
            throw ExecutionError.numericError(error)
        }
        state.incrementCounter()
    }

    private func output() {
        state.emitOutput(state.accumulator.value)
        observer.handle(.outputProduced(state.accumulator.value))
        state.incrementCounter()
    }

    private func halt() {
        state.setHalted()
        observer.handle(.halted)
    }

    private func operandAddress(from instruction: Instruction) throws -> MailboxAddress {
        guard case let .address(address) = instruction.operand else {
            state.setHalted()
            observer.handle(.error("Operand expected for instruction \(instruction.opcode)"))
            let encodedWord = (try? InstructionWord.encode(instruction)) ?? .zero
            throw ExecutionError.invalidInstruction(encodedWord)
        }
        return address
    }

    private func writeAccumulator(to address: MailboxAddress) throws {
        let value = state.accumulator.value
        do {
            let word = try numericPolicy.word(fromSigned: value)
            state.store(word: word, at: address)
        } catch let error as NumericError {
            state.setHalted()
            throw ExecutionError.numericError(error)
        }
    }
}
