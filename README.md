# CoreLittleManComputer

The Little Man Computer as a Swift package: a deterministic machine, an
assembler and disassembler, an actor that runs programs over time, and an
observable mirror for SwiftUI. It has no dependencies, builds in Swift 6
language mode with strict concurrency, and is the engine behind SparrowTek's
Little Man Computer apps.

```swift
import CoreLittleManComputer

let program = try Assembler().assemble(SamplePrograms.countdown.source)

var machine = Machine(program: program, inbox: [3])
machine.run()
print(machine.outbox)   // [3, 2, 1, 0]
```

## The machine

`Machine` is a value. It holds the 100 mailboxes, the accumulator, the
program counter, the in-basket and the out-basket, and `step()` performs one
fetch–execute cycle. Copies are snapshots, equality is structural, and it is
`Codable`, so saving, comparing and time-travelling are free.

| Register | Type | Range |
| --- | --- | --- |
| Mailbox | `Word` | `000...999` |
| Accumulator | `SignedWord` | `-999...999` |
| Program counter | `MailboxAddress` | `00...99` |
| In-basket card | `Word` | `000...999` |
| Out-basket value | `SignedWord` | `-999...999` |

The instruction set is the standard one:

| Code | Mnemonic | Effect |
| --- | --- | --- |
| `1xx` | `ADD` | accumulator += mailbox xx |
| `2xx` | `SUB` | accumulator -= mailbox xx |
| `3xx` | `STA` / `STO` | mailbox xx = accumulator |
| `5xx` | `LDA` | accumulator = mailbox xx |
| `6xx` | `BRA` | program counter = xx |
| `7xx` | `BRZ` | program counter = xx if accumulator is zero |
| `8xx` | `BRP` | program counter = xx if accumulator is zero or positive |
| `901` | `INP` | accumulator = next card in the in-basket |
| `902` | `OUT` | append accumulator to the out-basket |
| `000` | `HLT` / `COB` | stop |
| — | `DAT` | assembler directive: reserve a mailbox, optionally with a value |

### Where the specification is silent

The Little Man Computer leaves a few things undefined. This package decides
them explicitly, and every decision is covered by a test.

- **Overflow.** `ADD` and `SUB` compute the exact result. When it does not
  fit the accumulator, `Machine.overflowBehavior` decides: `.fault` (the
  default) stops the machine with `MachineFault.accumulatorOverflow`, naming
  the value; `.wrap` keeps the sign and the low three digits, so `600 + 600`
  gives `200`.
- **Storing a negative accumulator.** Mailboxes have no sign, so `STA` stores
  the ten's complement: `-1` becomes `999`. This keeps the common
  `SUB ONE / STA COUNT / BRP LOOP` idiom working.
- **Empty in-basket.** `INP` leaves the machine in `.awaitingInput` with the
  program counter still on the `INP`. Supply a card and step again.
- **Program counter.** It is incremented after the fetch and before the
  execute, so after `HLT` it points one past the halt, and it wraps from `99`
  to `00` like a two-digit counter.
- **Non-instructions.** Any word `000...099` executes as `HLT`. `4xx` words,
  and `9xx` words other than `901` and `902`, stop the machine with
  `MachineFault.invalidInstruction`, leaving the program counter on the
  offending mailbox.

## Assembly

```
     INP
     OUT      // Initialize output
LOOP BRZ QUIT // If the accumulator is 0, jump to QUIT
     SUB ONE
     OUT
     BRA LOOP
QUIT HLT
ONE  DAT 1
```

- One statement per line: `[label] mnemonic [operand]`. Comments start with
  `//`, `;` or `#`.
- Mnemonics are case-insensitive. Labels are matched case-insensitively too,
  keep the spelling you wrote, may end with a colon, and may not be mnemonics.
- Addressed instructions take a mailbox number `0...99` or a label. `DAT`
  takes a value `0...999`, a label (whose address becomes the value), or
  nothing (`000`). A line holding only a number is shorthand for `DAT`.

`Assembler.assemble(_:)` returns a `Program`: the memory image plus one
`Program.Line` per filled mailbox with its label, source line and whether it
is data. It throws `AssemblyError`, which carries every `AssemblyDiagnostic`
found, each with a line, a column and a human-readable message.
`Disassembler` turns a program or a memory image back into source that
reassembles to the same words.

## Running programs over time

`ExecutionEngine` is an actor that owns a machine and adds pacing, pausing,
breakpoints, a bounded trace and an event stream. Every method is safe to
call from any task.

```swift
let engine = ExecutionEngine(program: program, inbox: [5])
await engine.addBreakpoint(4)

switch await engine.run(speed: .hertz(2)) {
case .halted:                 print(await engine.machine.outbox)
case .awaitingInput:          await engine.provideInput(7)
case .breakpoint(let mailbox): print("stopped before \(mailbox)")
case .faulted(let fault):     print(fault)
case .paused, .cycleLimitReached, .alreadyRunning: break
}
```

`run` suspends between instructions, so `pause()`, `provideInput(_:)` and
`edit(_:)` get through while it runs; cancelling the calling task also ends
the run. A run resumed at a breakpoint executes that instruction first.

`events()` returns an `AsyncStream<ExecutionEvent>` that begins with a
snapshot of the current state and then reports every change with the full
new `Machine` and the `MachineChange` that caused it, plus `runStarted` and
`runFinished`. Any number of subscribers can listen.

## SwiftUI

`ObservableMachine` is a `@MainActor @Observable` mirror of an engine. Put it
in the environment and keep it live with a task modifier:

```swift
struct EditorPresenter: View {
    @Environment(ObservableMachine.self) private var observable

    var body: some View {
        EditorView()
            .task { await observable.observe() }
    }
}
```

Views read `machine`, `lastCycle`, `lastChange`, `isRunning` and
`lastRunOutcome`; `lastCycle.readAddress` and `writtenAddress` are what a
memory grid highlights. The forwarding methods (`step()`, `run(speed:)`,
`pause()`, `reset()`, `provideInput(_:)`, `write(_:at:)`, `load(_:)`) are
conveniences; calling the engine directly is reflected just the same.

## Persistence

`Program`, `Machine`, `Cycle`, `Instruction` and `MachineFault` are `Codable`.
Words, signed words and addresses encode as plain integers and refuse
out-of-range values when decoded; `Memory` encodes as an array of exactly 100
integers.

## Samples

`SamplePrograms.all` holds six classic programs, including the Wikipedia
subtraction and countdown examples, each with sample inputs and the outputs
it produces. `Docs/examples` has the same programs as `.lmc` files.

## Layout

```
Sources/CoreLittleManComputer
├── Core          Word, SignedWord, MailboxAddress, Memory
├── Instructions  Opcode, Instruction
├── Machine       Machine, Cycle, status, faults and outcomes
├── Assembly      Assembler, Disassembler, Program, diagnostics
├── Execution     ExecutionEngine, speed and events
├── Observation   ObservableMachine
└── Samples       SamplePrograms
```

Build and test with `swift build` and `swift test`. Tests use Swift Testing.
