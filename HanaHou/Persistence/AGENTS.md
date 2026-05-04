# AGENTS.md — HanaHou/Persistence/

The persistence boundary for deck and card management. Exposes `DeckStore` and `CardStore` to the rest of the app; hides Core Data.

## Current contents

| File | Purpose |
|------|---------|
| `DeckStore.swift` | `DeckStore` protocol (fetchAll/create/update/delete + change publisher) and `DeckStoreError`. |
| `InMemoryDeckStore.swift` | Non-persisted `DeckStore` implementation used by view-model tests and previews. Deterministic via an injectable clock. |
| `CoreDataDeckStore.swift` | Production `DeckStore` backed by `NSManagedObjectContext`. Re-runs `DeckNameValidator` before save; emits on `NSManagedObjectContextDidSave`; the Core Data `Nullify` rule detaches cards without deleting them. |
| `CardStore.swift` | `CardStore` protocol (fetchAll, fetchInDeck, create, update, delete + change publisher) and `CardStoreError`. Update/delete on unknown id are silent no-ops that do not emit (D033). |
| `InMemoryCardStore.swift` | Non-persisted `CardStore` implementation with an injectable clock. Includes a test-only `simulateDeckDeleted(deckId:)` helper for view-model tests that need the orphan path without a Core Data stack. |
| `CoreDataCardStore.swift` | Production `CardStore` backed by `NSManagedObjectContext`. Observes `NSManagedObjectContextDidSave` on the shared context so deck deletions trigger card-side refreshes. `fetchInDeck(deckId:)` uses `ANY decks.id == %@` through the many-to-many inverse. |

## Directives

- Core Data entities are accessed via KVO (`setValue(_:forKey:)` / `value(forKey:)`) to stay decoupled from generated managed-object classes.
- Validation is enforced here as defense-in-depth — primary enforcement lives in the domain validators.
- Save failures must roll back the context and throw the corresponding `*StoreError.persistenceFailed(underlying:)`; never `fatalError`.
- The store protocols are the only things upstream code should depend on.
- Orphan behavior is a Core Data feature (Nullify rule on `Card.decks`) — `InMemoryCardStore` provides the `simulateDeckDeleted(...)` test helper because it has no deck store to observe.
