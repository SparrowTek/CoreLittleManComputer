public enum ExecutionError: Error, Sendable, Equatable {
    case halted
    case awaitingInput
    case mailboxOutOfBounds(MailboxAddress)
    case invalidInstruction(Word)
    case numericError(NumericError)
    case breakpointHit(MailboxAddress)
}

public enum ExecutionSchedule: Sendable {
    case unlimited
    case hertz(Double)
    case interval(TimeInterval)
    case nanoseconds(UInt64)

    fileprivate func delayNanoseconds() -> UInt64? {
        switch self {
        case .unlimited:
            return nil
        case .hertz(let hz) where hz > 0:
            return UInt64(Double(NSEC_PER_SEC) / hz)
        case .interval(let seconds) where seconds > 0:
            return UInt64(seconds * Double(NSEC_PER_SEC))
        case .nanoseconds(let ns):
            return ns
        default:
            return nil
        }
    }
}

/// Virtual machine runtime for executing Little Man Computer programs.
///
/// - Note: `ExecutionEngine` is not internally synchronised. Mutate and call
///   methods from a single task/queue unless you provide external coordination.
public final class ExecutionEngine: @unchecked Sendable {
    public let program: Program
    public let numericPolicy: NumericPolicy
    private(set) public var state: ProgramState
    private let observer: ExecutionObserver
    private var inboxBox: InboxBox?
    private var outboxBox: OutboxBox?
    private var breakpoints: Set<MailboxAddress>
    private let eventStream: AsyncStream<ExecutionEvent>
    private let eventContinuation: AsyncStream<ExecutionEvent>.Continuation

    public var events: AsyncStream<ExecutionEvent> { eventStream }

    public init(program: Program,
                initialState: ProgramState = ProgramState(),
                numericPolicy: NumericPolicy = .trapOnOverflow,
                observer: ExecutionObserver = NoOpObserver(),
                inboxProvider: (any InboxProviding)? = nil,
                outboxConsumer: (any OutboxConsuming)? = nil,
                breakpoints: Set<MailboxAddress> = []) {
        self.program = program
        let pair = AsyncStream<ExecutionEvent>.makeStream()
        self.eventStream = pair.stream
        self.eventContinuation = pair.continuation
        var workingState = initialState
        workingState.ensureMemoryInitialized(with: program.memoryImage)
        self.state = workingState
        self.numericPolicy = numericPolicy
        self.observer = observer
        if let inboxProvider {
            self.inboxBox = InboxBox(provider: inboxProvider)
        } else {
            self.inboxBox = nil
        }
        if let outboxConsumer {
            self.outboxBox = OutboxBox(consumer: outboxConsumer)
        } else {
            self.outboxBox = nil
        }
        self.breakpoints = breakpoints
    }

    deinit {
        eventContinuation.finish()
    }

    public func setInboxProvider(_ provider: some InboxProviding) {
        inboxBox = InboxBox(provider: provider)
    }

    public func clearInboxProvider() {
        inboxBox = nil
    }

    public func setOutboxConsumer(_ consumer: some OutboxConsuming) {
        outboxBox = OutboxBox(consumer: consumer)
    }

    public func clearOutboxConsumer() {
        outboxBox = nil
    }

    public func addBreakpoint(_ address: MailboxAddress) {
        breakpoints.insert(address)
    }

    public func removeBreakpoint(_ address: MailboxAddress) {
        breakpoints.remove(address)
    }

    public func removeAllBreakpoints() {
        breakpoints.removeAll()
    }

    @discardableResult
    public func runUntilHalt(maxCycles: Int? = nil) throws -> ProgramState {
        var executed = 0
        while !state.halted {
            if let maxCycles, executed >= maxCycles { break }
            try step()
            executed += 1
        }
        return state
    }

    public func runNext(_ cycles: Int) throws {
        guard cycles >= 0 else { return }
        for _ in 0..<cycles {
            guard !state.halted else { break }
            try step()
        }
    }

    public func run(schedule: ExecutionSchedule = .unlimited,
                    maxCycles: Int? = nil,
                    shouldStop: @Sendable (ProgramState) -> Bool = { _ in false }) async throws {
        var executed = 0
        let delay = schedule.delayNanoseconds()
        while !state.halted {
            if let maxCycles, executed >= maxCycles { break }
            if shouldStop(state) { break }
            try Task.checkCancellation()
            try step()
            executed += 1
            if let delay {
                try await Task.sleep(nanoseconds: delay)
            }
        }
    }

    public func step() throws {
        guard !state.halted else {
            throw ExecutionError.halted
        }

        let counter = state.counter
        guard MailboxAddress.validRange.contains(counter.rawValue) else {
            throw ExecutionError.mailboxOutOfBounds(counter)
        }

        emit(.cycleStarted(cycle: state.cycles, counter: counter))

        let word = state.word(at: counter)
        let decoded: InstructionWord.Decoded
        do {
            decoded = try InstructionWord(word).decode()
        } catch {
            state.setHalted()
            emit(.error("Invalid instruction word \(word.rawValue)"))
            throw ExecutionError.invalidInstruction(word)
        }

        switch decoded {
        case .data:
            state.setHalted()
            emit(.error("Encountered data at \(counter.rawValue)"))
            throw ExecutionError.invalidInstruction(word)
        case .instruction(let instruction):
            state.record(instruction: instruction)
            emit(.instructionDecoded(instruction))
            try execute(instruction)
            emit(.instructionExecuted(instruction, state))
            state.incrementCycle()
            emit(.cycleCompleted(cycle: state.cycles, state: state))
            if breakpoints.contains(state.counter) {
                emit(.breakpointHit(state.counter))
                throw ExecutionError.breakpointHit(state.counter)
            }
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
        if var box = inboxBox {
            let value = box.dequeue()
            inboxBox = box
            if let value {
                try receiveInput(value)
                return
            }
        }
        if let value = state.dequeueInbox() {
            try receiveInput(value)
        } else {
            emit(.inputRequested)
            throw ExecutionError.awaitingInput
        }
    }

    private func output() {
        let value = state.accumulator.value
        state.emitOutput(value)
        if var box = outboxBox {
            box.enqueue(value)
            outboxBox = box
        }
        emit(.outputProduced(value))
        state.incrementCounter()
    }

    private func halt() {
        state.setHalted()
        emit(.halted)
    }

    private func operandAddress(from instruction: Instruction) throws -> MailboxAddress {
        guard case let .address(address) = instruction.operand else {
            state.setHalted()
            emit(.error("Operand expected for instruction \(instruction.opcode)"))
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

    private func receiveInput(_ value: Int) throws {
        do {
            let accumulator = try numericPolicy.accumulator(from: value)
            state.updateAccumulator(accumulator)
        } catch let error as NumericError {
            state.setHalted()
            throw ExecutionError.numericError(error)
        }
        state.incrementCounter()
    }

    private func emit(_ event: ExecutionEvent) {
        observer.handle(event)
        eventContinuation.yield(event)
    }
}

private struct InboxBox: Sendable {
    var provider: any InboxProviding

    mutating func dequeue() -> Int? {
        provider.dequeue()
    }
}

private struct OutboxBox: Sendable {
    var consumer: any OutboxConsuming

    mutating func enqueue(_ value: Int) {
        consumer.enqueue(value)
    }
}
import Foundation
