# CoreLittleManComputer

CoreLittleManComputer is the shared engine for SparrowTek's Little Man Computer experiences.

## Current Status
- Stage 1 scaffolding: the module map, core types, and testing harness have been reset.
- Execution, assembler, and persistence layers are under active redevelopment.

## Directory Overview
- `Sources/CoreLittleManComputer/Core` – fundamental value types and numeric policies.
- `Sources/CoreLittleManComputer/InstructionSet` – opcode metadata and instruction representation.
- `Sources/CoreLittleManComputer/Program` – program definition and mutable execution state snapshots.
- `Sources/CoreLittleManComputer/Assembler` – assembly pipeline (placeholder).
- `Sources/CoreLittleManComputer/Execution` – virtual machine scaffolding.
- `Sources/CoreLittleManComputer/IO` – inbox/outbox protocols and helpers.
- `Sources/CoreLittleManComputer/Diagnostics` – execution events and observers.
- `Sources/CoreLittleManComputer/Persistence` – serialization hooks.
- `Sources/CoreLittleManComputer/Support` – fixtures shared with tests.

See `Docs/architecture.md` for the evolving design notes.
