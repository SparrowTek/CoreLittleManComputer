# CoreLittleManComputer Architecture Notes

## Overview
The package models the Little Man Computer specification as a layered architecture:

1. **Core** – canonical numeric representations (`Word`, `Accumulator`, `MailboxAddress`, `NumericPolicy`).
2. **Instruction Set** – opcode metadata and typed instructions that can be encoded/decoded to memory words.
3. **Program** – immutable program images plus mutable execution state snapshots.
4. **Execution** – fetch/decode/execute engine with pluggable policies and observers.
5. **Assembler** – source-to-program pipeline (tokenise → parse → resolve → emit).
6. **I/O** – protocol-based inbox/outbox abstractions.
7. **Diagnostics** – event stream for tooling and UI layers.
8. **Persistence** – serialisation helpers for saving/restoring programs and state.

### Diagnostics Notes
- `ExecutionEngine` emits `ExecutionEvent` entries via both an injected observer and an `AsyncStream` for async consumers.
- `ProgramState` keeps a bounded trace buffer; `TraceFormatter` and `StateSnapshotFormatter` provide CLI-friendly renderings.
- `ExecutionSchedule` and `stateStream` outline recommended run-loop integrations for CLI/UIs.

### Persistence Notes
- `ProgramSnapshot`/`ProgramStateSnapshot` capture Codable representations validated against LMC bounds.
- `ProgramSerializer` and `ProgramStateSerializer` emit/restore JSON suitable for CLI storage; add schema versioning before shipping.
- `ProgramTextCodec` wraps assembling/disassembling for import/export workflows.
