# AGENTS.md — HanaHou/ViewModels/

Main-actor `ObservableObject` view models. Own UI state, talk to `DeckStore`, expose `@Published` properties to SwiftUI.

## Current contents

| File | Purpose |
|------|---------|
| `DeckEditorViewModel.swift` | Drives `DeckEditorView`. Two modes (`create`, `edit(DeckSnapshot)`), bindable fields for name/front/back language, `validateName()`, `submit()`, plus a `message(for:)` helper that produces distinct localizable strings per `DeckNameError` case. |
| `DeckListViewModel.swift` | Drives `DeckListView`. Subscribes to `store.changes`, runs `DeckListComposer` to produce `items`. Enforces the All Cards invariants via `rename(item:to:)` / `delete(item:)` guards that throw `AllCardsActionError.notAllowed`. |

## Directives

- View models depend on the `DeckStore` protocol, never on a concrete store — that's how view-model tests run without a simulator.
- Annotate with `@MainActor`; publish via `@Published`; keep pure value types in/out where possible.
- Clock is injected for deterministic timestamps in tests.
- Do NOT import Core Data here.
