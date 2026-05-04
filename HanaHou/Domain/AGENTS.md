# AGENTS.md — HanaHou/Domain/

Pure domain services. No SwiftUI, no Core Data. Everything here operates on plain Swift values so it can be unit-tested without the simulator.

## Current contents

| File | Purpose |
|------|---------|
| `DeckNameValidator.swift` | Validates a proposed deck name against the current deck set. Rules: empty, reserved (`"All Cards"`, trimmed + case-insensitive), duplicate (trimmed + case-sensitive, excluding the edit target). |
| `DeckOrderingStrategy.swift` | `DeckOrderingStrategy` protocol plus the P0 implementation `CreationDateAscendingOrdering`. D009 swappable-strategy pattern. |
| `DeckListComposer.swift` | `DeckListComposer.compose(userDecks:strategy:)` produces `[.allCards, .deck(…), …]` for `DeckListView`. `.allCards` sits at a fixed position independent of the strategy. |
| `CardTextValidator.swift` | Validates a `CardDraft`. Rules: non-empty `frontText`, non-empty `backText` (both trimmed with `.whitespacesAndNewlines`). Front is checked before back. |
| `CardOrderingStrategy.swift` | `CardOrderingStrategy` protocol plus `CardCreationDateAscendingOrdering`. Card-side sibling of `DeckOrderingStrategy` (D032 — not a generic). |

## Directives

- Add a new strategy as a new file in this folder, with its own tests in `HanaHouTests/Domain/`.
- Do not add dependencies on `DeckStore` or `CardStore`; domain services take values in and return values out.
- TDD per D007 / D021: example-based XCTest in `HanaHouTests/Domain/` first, then implementation here.
