# AGENTS.md — HanaHouTests/Persistence/

Tests for the `DeckStore` and `CardStore` implementations under `HanaHou/Persistence/`.

## Current contents

| File | Covers |
|------|--------|
| `InMemoryDeckStoreTests.swift` | B1/B2/B3 validator parity, B5 create round-trip, B6 edit round-trip, change-publisher emissions (and non-emissions on failed mutations). |
| `CoreDataDeckStoreTests.swift` | B1/B2/B3 parity, B5 create round-trip, B6 edit round-trip, B11 delete detaches cards without deleting them. Uses a fresh `NSInMemoryStoreType` `NSPersistentContainer` per test. |
| `InMemoryCardStoreTests.swift` | C1/C2 validation, C3 create round-trip (clock-driven timestamps, many-to-many `deckIds`), C4 edit round-trip (preserves id/createdAt/deckIds, bumps `updatedAt`), C5 delete, C9 unknown-id silent no-op, C10 change-publisher emission on success / non-emission on failure, plus coverage of the `simulateDeckDeleted(deckId:)` test helper. |
| `CoreDataCardStoreTests.swift` | Mirrors the in-memory suite against the Core Data backing, plus C6 (card becomes an orphan when its only deck is deleted) and B11-C (deck deletion preserves cards still attached to other decks) — both use a shared `NSManagedObjectContext` with `CoreDataDeckStore`. |

## Directives

- Each test gets a fresh store — no shared state.
- Inject the clock to pin `createdAt` / `updatedAt` deterministically.
- When asserting order-insensitive equality, sort by `(createdAt, id.uuidString)` in the test helper.
- Tests for shared-context behavior (C6, B11-C) construct both the deck and card store against a single `container.viewContext`.
