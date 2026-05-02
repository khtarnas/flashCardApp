# AGENTS.md — HanaHou/Persistence/

The persistence boundary for deck management. Exposes `DeckStore` to the rest of the app; hides Core Data.

## Current contents

| File | Purpose |
|------|---------|
| `DeckStore.swift` | `DeckStore` protocol (fetchAll/create/update/delete + change publisher) and `DeckStoreError`. |
| `InMemoryDeckStore.swift` | Non-persisted implementation used by view-model tests and previews. Deterministic via an injectable clock. |
| `CoreDataDeckStore.swift` | Production implementation backed by `NSManagedObjectContext`. Re-runs `DeckNameValidator` before save; emits on `NSManagedObjectContextDidSave`; relies on the Core Data `Nullify` rule to detach cards without deleting them. |

## Directives

- Core Data entities are accessed via KVO (`setValue(_:forKey:)` / `value(forKey:)`) to stay decoupled from the generated managed-object classes.
- Name validation is enforced here as defense-in-depth — primary enforcement lives in `DeckNameValidator`.
- Save failures must roll back the context and throw `DeckStoreError.persistenceFailed(underlying:)`; never `fatalError`.
- The `DeckStore` protocol is the only thing upstream code should depend on.
