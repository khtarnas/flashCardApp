# AGENTS.md — HanaHou/ViewModels/

Main-actor `ObservableObject` view models. Own UI state, talk to `DeckStore` / `CardStore`, expose `@Published` properties to SwiftUI.

## Current contents

| File | Purpose |
|------|---------|
| `DeckEditorViewModel.swift` | Drives `DeckEditorView`. Two modes (`create`, `edit(DeckSnapshot)`), bindable fields for name/front/back language, `validateName()`, `submit()`, plus a `message(for:)` helper that produces distinct localizable strings per `DeckNameError` case. |
| `DeckListViewModel.swift` | Drives `DeckListView`. Subscribes to `store.changes`, runs `DeckListComposer` to produce `items`. Enforces the All Cards invariants via `rename(item:to:)` / `delete(item:)` guards that throw `AllCardsActionError.notAllowed`. |
| `CardEditorViewModel.swift` | Drives `CardEditorView`. Two modes (`create(deckId: UUID?)`, `edit(CardSnapshot)`), bindable `frontText`/`backText`, independent `@Published` `frontError`/`backError` channels, `validate()` (applies both non-empty rules without short-circuiting), `submit()` (create or update+refetch via `store.fetchAll()`), and `delete()` (no-op in `.create` mode). |
| `CardListViewModel.swift` | Drives the per-Deck `CardListView`. Subscribes to `CardStore.changes` and re-queries `fetchInDeck(deckId:)` on each signal, applying the injected `CardOrderingStrategy`. Exposes `items: [CardRowItem]` and `snapshot(forRowId:)` for row-tap routing. |
| `AllCardsViewModel.swift` | Drives `AllCardsView`. Same shape as `CardListViewModel` but queries `fetchAll()` — surfaces every card, orphans included. |

## Directives

- View models depend on the store protocols (`DeckStore`, `CardStore`), never on a concrete store — that's how view-model tests run without a simulator.
- Annotate with `@MainActor`; publish via `@Published`; keep pure value types in/out where possible.
- Clock is injected for deterministic timestamps in tests.
- Do NOT import Core Data here.
