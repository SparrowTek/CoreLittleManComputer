# Architecture

## Layers

```
Samples ──▶ Assembly ──▶ Machine ──▶ Execution ──▶ Observation
               │            │
               └──── Instructions ◀── Core
```

- **Core** – `Word`, `SignedWord`, `MailboxAddress` and `Memory`. Each numeric
  type is a `RawRepresentable` struct whose only failable entry point is
  `init?(rawValue:)`; `init(wrapping:)` gives the modular result a physical
  register would show, and integer literals trap on out-of-range constants the
  way `UInt8(300)` does. `Memory` always holds exactly 100 words so reads and
  writes by address cannot fail.
- **Instructions** – `Opcode` (the ten operations, with mnemonics and aliases)
  and `Instruction`, an enum whose addressed cases carry their mailbox. An
  instruction can never be missing an operand or carry a spurious one.
- **Machine** – the value type that is the computer. `step()` is the only
  place LMC semantics live. It returns a `StepOutcome`; the machine's `status`
  says what can happen next. Faults leave the program counter on the
  offending instruction. `run(maxCycles:)` is a synchronous loop for tests and
  batch use.
- **Assembly** – a two-pass assembler that collects every diagnostic before
  throwing a typed `AssemblyError`, and a disassembler whose output
  reassembles to the same memory. `Program` is the memory image plus listing
  metadata (`Program.Line`) so front-ends can map between addresses, labels
  and source lines.
- **Execution** – `ExecutionEngine`, an actor. It never spawns tasks: `run`
  is a structured loop that suspends between instructions, checks a pause
  flag and task cancellation, and yields every 256 cycles at maximum speed so
  other messages get through. Events are broadcast through per-subscriber
  `AsyncStream` continuations; terminated subscribers are dropped lazily on
  the next publish.
- **Observation** – `ObservableMachine`, a `@MainActor @Observable` mirror.
  It is fed only by the engine's event stream, so its state is always
  internally consistent; `observe()` is structured and meant for a `.task`
  modifier.

## Invariants worth knowing

- Every `ExecutionEvent.machineChanged` carries the complete `Machine`, so a
  subscriber that drops events (a UI using `.bufferingNewest`) is still
  correct after the next one.
- `events()` yields the snapshot before registering the continuation, inside
  the actor, so no change can slip between the snapshot and the subscription.
- `reset` and `load` set the pause flag, so a run in progress ends with
  `.paused` before it can execute on the fresh machine.
- The assembler still emits a placeholder mailbox for a line with an error,
  so labels on later lines keep their addresses and later diagnostics stay
  meaningful.

## Concurrency model

Swift 6 language mode, strict concurrency, no `@unchecked Sendable`. Every
public value type is `Sendable` by construction; the only reference types are
the `ExecutionEngine` actor and the main-actor `ObservableMachine`.
