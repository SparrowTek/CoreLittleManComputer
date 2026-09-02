import Foundation

/// What the machine does when `ADD` or `SUB` produces a result outside
/// ``SignedWord/range``.
///
/// The Little Man Computer specification leaves this case undefined, so the
/// choice is explicit and travels with the machine state.
public enum OverflowBehavior: String, Hashable, Sendable, Codable, CaseIterable {
    /// The machine stops with ``MachineFault/accumulatorOverflow(value:address:)``.
    ///
    /// This is the default: nothing is silently lost, and the fault names
    /// the value that could not be represented.
    case fault

    /// The accumulator keeps the sign and the low three digits of the result,
    /// as a three-digit display would. `999 + 1` becomes `0` and `600 + 600`
    /// becomes `200`.
    case wrap
}

/// Whether the machine can execute its next instruction.
public enum MachineStatus: Hashable, Sendable, Codable {
    /// The next instruction can be executed.
    case ready

    /// `INP` found the in-basket empty. Supply input, then step again; the
    /// program counter still points at the `INP` instruction.
    case awaitingInput

    /// `HLT` was executed.
    case halted

    /// Execution stopped because of an error in the program.
    case faulted(MachineFault)

    /// `true` once the machine has halted or faulted.
    public var hasStopped: Bool {
        switch self {
        case .halted, .faulted: true
        case .ready, .awaitingInput: false
        }
    }
}

/// An error in the running program that stops the machine.
///
/// A fault leaves the program counter pointing at the instruction that caused
/// it, so the offending mailbox can be highlighted.
public enum MachineFault: Error, Hashable, Sendable, Codable {
    /// The word at `address` does not decode to an instruction (a `4xx` word,
    /// or a `9xx` word other than `901` and `902`).
    case invalidInstruction(word: Word, address: MailboxAddress)

    /// `ADD` or `SUB` at `address` produced `value`, which the accumulator
    /// cannot hold. Only raised under ``OverflowBehavior/fault``.
    case accumulatorOverflow(value: Int, address: MailboxAddress)
}

extension MachineFault: CustomStringConvertible, LocalizedError {
    public var description: String {
        switch self {
        case .invalidInstruction(let word, let address):
            "Mailbox \(address) holds \(word), which is not an instruction."
        case .accumulatorOverflow(let value, let address):
            "The instruction at mailbox \(address) produced \(value), which is outside the accumulator's range of \(SignedWord.range.lowerBound) to \(SignedWord.range.upperBound)."
        }
    }

    public var errorDescription: String? {
        description
    }
}

/// The result of asking a ``Machine`` to execute one instruction.
public enum StepOutcome: Hashable, Sendable {
    /// An instruction ran to completion; `Cycle` records what it did.
    case executed(Cycle)

    /// `INP` found the in-basket empty. The machine is unchanged apart from
    /// its status, which is now ``MachineStatus/awaitingInput``.
    case awaitingInput

    /// The instruction could not run. The machine's status is now
    /// ``MachineStatus/faulted(_:)``.
    case faulted(MachineFault)

    /// Nothing happened because the machine had already halted or faulted.
    case notRunning
}

/// Why a run of many instructions came to an end.
public enum RunOutcome: Hashable, Sendable {
    /// `HLT` was executed.
    case halted

    /// The program caused a fault.
    case faulted(MachineFault)

    /// `INP` needs a value that the in-basket does not have.
    case awaitingInput

    /// The next instruction is at a breakpoint. Only ``ExecutionEngine`` reports this.
    case breakpoint(MailboxAddress)

    /// ``ExecutionEngine/pause()`` was called or the task was cancelled. Only ``ExecutionEngine`` reports this.
    case paused

    /// The cycle limit passed to the run was reached.
    case cycleLimitReached

    /// A run was already in progress on the engine, so this call did nothing. Only ``ExecutionEngine`` reports this.
    case alreadyRunning
}
