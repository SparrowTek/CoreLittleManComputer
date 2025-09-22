# CoreLittleManComputer Backlog

## Persistence
- Add migration utilities to upgrade older snapshot versions (e.g. v0 -> v1) and surface schema metadata in CLI tooling.

## Execution
- Investigate watchpoints and cycle-based breakpoints for richer debugging support.
- Explore visual debugger integration (timeline of accumulator/mailboxes, breakpoints UI hooks).

## Diagnostics
- Add optional JSON event formatter for structured logging / telemetry.

## Packaging
- Provide SwiftPM plugin or script for converting `.lmc` sources to JSON snapshots.

## Tooling
- Split Swift Testing suites into thematic files (`AssemblerTests`, `ExecutionTests`, `PersistenceTests`) once the surface area grows further.
