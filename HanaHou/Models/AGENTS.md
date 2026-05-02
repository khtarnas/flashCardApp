# AGENTS.md — HanaHou/Models/

Plain Swift value types and enums shared across the deck-management feature. No SwiftUI, no Core Data, no view-model logic.

## Current contents

| File | Purpose |
|------|---------|
| `Language.swift` | `Language` enum (English, Japanese, Spanish, Mandarin, Hawaiian, other). Includes a `displayName` extension. |
| `DeckSnapshot.swift` | Immutable value representing a Deck row as seen by the domain layer. Crosses the store boundary. |
| `DeckDraft.swift` | Mutable value carrying a proposed deck state from view model to store. |
| `DeckListItem.swift` | Sum type representing a row in the deck list: `.allCards` or `.deck(DeckSnapshot)`. |
| `DeckNameError.swift` | `.empty`, `.reserved`, `.duplicate` — distinct cases per design §6. |
| `AllCardsActionError.swift` | `.notAllowed` — thrown when code attempts to edit or delete the All Cards entry. |

## Directives

- Keep types here pure and free of framework dependencies (Foundation only).
- Behavior for these types is exercised via downstream consumers (validator, store, view models). No per-file test is required unless behavior lives here.
- Adding a language case is a no-op migration because storage is raw-String.
