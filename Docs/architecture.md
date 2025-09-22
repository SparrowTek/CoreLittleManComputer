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

## Status
- Core types, instruction metadata, and scaffolding for higher layers are in place.
- Assembler, execution semantics, diagnostics emission, and persistence are pending implementation in upcoming stages.

## Next Steps
- Implement Stage 2 tasks (complete `Word` utilities, numeric policies, encode/decode helpers).
- Flesh out Stage 3 program representations and state management.

Refer to `plan.md` at the repository root for the full roadmap.
