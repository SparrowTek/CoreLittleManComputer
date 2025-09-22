# CoreLittleManComputer Backlog

## Persistence
- Add snapshot schema metadata (e.g. tool versions, creation timestamp) and migration helpers so future versions can upgrade older JSON payloads gracefully.

## Execution
- Investigate watchpoints and cycle-based breakpoints for richer debugging support.

## Tooling
- Split Swift Testing suites into thematic files (`AssemblerTests`, `ExecutionTests`, `PersistenceTests`) once the surface area grows further.
