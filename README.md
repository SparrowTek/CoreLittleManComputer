# CoreLittleManComputer

CoreLittleManComputer is the shared engine for SparrowTek's Little Man Computer experiences.

## Current Capabilities
- Assemble Little Man Computer source into a compiled memory image or JSON snapshot.
- Execute programs via synchronous or async runners with breakpoint, inbox/outbox, and diagnostics hooks.
- Persist and restore program/state snapshots; stream state updates to CLIs or SwiftUI via adapters.
- Format traces and state snapshots for logs/CLI and disassemble compiled programs back to assembly.

## Directory Overview
- `Sources/CoreLittleManComputer/Core` – fundamental value types and numeric policies.
- `Sources/CoreLittleManComputer/InstructionSet` – opcode metadata and instruction representation.
- `Sources/CoreLittleManComputer/Program` – program definition and mutable execution state snapshots.
- `Sources/CoreLittleManComputer/Assembler` – assembly/disassembly pipeline.
- `Sources/CoreLittleManComputer/Execution` – virtual machine core and run control.
- `Sources/CoreLittleManComputer/IO` – inbox/outbox protocols and helpers.
- `Sources/CoreLittleManComputer/Diagnostics` – execution events and observers.
- `Sources/CoreLittleManComputer/Persistence` – serialization hooks.
- `Sources/CoreLittleManComputer/Support` – fixtures shared with tests.

See `Docs/architecture.md` for the evolving design notes.

## Quick Start

```swift
import CoreLittleManComputer

let source = """
    LDA ONE
    ADD INPUT
    OUT
    HLT
    ONE DAT 1
    INPUT DAT 0
    """

let codec = ProgramTextCodec()
let program = try codec.assemble(source)

let engine = ExecutionEngine(program: program, initialState: ProgramState(inbox: [5]))
try engine.runUntilHalt()
print(engine.state.outbox) // [6]

let serializer = ProgramSerializer(prettyPrinted: true)
let json = try serializer.exportJSON(program)
let restoredProgram = try serializer.importJSON(json)
```

## Sample Programs
- `Docs/examples/adder.lmc` – Adds constants and inbox values, demonstrating I/O and data directives.
- `Docs/examples/loop.lmc` – Countdown loop showcasing branching instructions and halt conditions.

Each sample includes comments outlining expected inbox/outbox behaviour for regression testing.

## CLI Integration Notes
- Use `ProgramTextCodec` to load `.lmc` files and `ProgramSerializer` to persist compiled snapshots.
- `ExecutionEngine.stateStream()` provides an `AsyncStream<ProgramState>` for progress updates; pair it with `TraceFormatter`/`StateSnapshotFormatter` for human-readable logs.
- `Scripts/run-ci.sh` offers a quick validation hook (`swift build && swift test`).
