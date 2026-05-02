# AGENTS.md — HanaHouTests/Persistence/

Tests for the `DeckStore` implementations under `HanaHou/Persistence/`.

## Current contents

| File | Covers |
|------|--------|
| `InMemoryDeckStoreTests.swift` | B1/B2/B3 validator parity, B5 create round-trip, B6 edit round-trip, change-publisher emissions (and non-emissions on failed mutations). |
| `CoreDataDeckStoreTests.swift` | B1/B2/B3 parity, B5 create round-trip, B6 edit round-trip, B11 delete detaches cards without deleting them. Uses a fresh `NSInMemoryStoreType` `NSPersistentContainer` per test. |

## Directives

- Each test gets a fresh store — no shared state.
- Inject the clock to pin `createdAt` / `updatedAt` deterministically.
- When asserting order-insensitive equality, sort by `(createdAt, id.uuidString)` in the test helper.
