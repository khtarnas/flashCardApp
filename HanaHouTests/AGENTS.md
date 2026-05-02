# AGENTS.md — HanaHouTests/

Unit tests for HanaHou using XCTest.

## Current contents

| File | Purpose |
|------|---------|
| `HanaHouTests.swift` | Default test file (Xcode template — to be replaced) |

## Directives

- Tests are written BEFORE implementation (TDD).
- Test domain logic: data model operations, business rules, data retention.
- Use in-memory Core Data stores for test isolation (`PersistenceController(inMemory: true)`).
- Name test files to match the source file they test (e.g., `DeckTests.swift` for `Deck` logic).
- When adding subdirectories, create an `AGENTS.md` in each.
