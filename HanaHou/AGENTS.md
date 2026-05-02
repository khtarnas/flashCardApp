# AGENTS.md — HanaHou/ (App Source)

Main application source for HanaHou.

## Current contents

| Path | Purpose |
|------|---------|
| `HanaHouApp.swift` | App entry point and composition root. Builds the Core Data stack, vends a `DeckStore`, picks the ordering strategy, and hosts `DeckManagementRootView`. |
| `Persistence.swift` | Owns the Core Data stack (`PersistenceController`). Vends a `CoreDataDeckStore` via `makeDeckStore()`. Throws on load failure rather than calling `fatalError`. |
| `HanaHou.xcdatamodeld/` | Core Data model (`Deck`, `Card` entities with a many-to-many relationship). Versioned; v2 is current. |
| `Assets.xcassets/` | App icons and color assets. |
| `Models/` | Plain Swift value types and enums used across the feature. |
| `Domain/` | Pure domain services (validation, ordering, list composition) — no SwiftUI, no Core Data. |
| `Persistence/` | `DeckStore` protocol plus its Core Data and in-memory implementations. |
| `ViewModels/` | Main-actor `ObservableObject` view models bridging views to domain + persistence. |
| `Views/` | SwiftUI view layer for deck management. |

## Directives

- New source code goes in the appropriate subdirectory; add one when a new concern appears.
- Every subdirectory must have an `AGENTS.md` (D005).
- SwiftUI + Core Data only in P0 (tech.md). No third-party dependencies.
- Core Data entities must match `docs/data-model.md`.
- No network calls in P0 or P1 (D002).
- Views never touch Core Data directly — they go through view models, which go through `DeckStore`.
