# AGENTS.md — HanaHouTests/ViewModels/

Tests for the `@MainActor` view models under `HanaHou/ViewModels/`.

## Current contents

| File | Covers |
|------|--------|
| `DeckEditorViewModelTests.swift` | Initialization in both modes, B1/B2/B3 validation gating, B4 distinct error messages, B5 create success, B6 edit success with `updatedAt` advancing. |
| `DeckListViewModelTests.swift` | B8 (`.allCards` invariants), B9 (user-deck subsequence matches strategy), B10 (store mutations propagate), All Cards rename/delete defense-in-depth. |
| `CardEditorViewModelTests.swift` | C1 (empty front), C2 (empty back, both-empty concurrent-errors surfacing on independent `@Published` channels), C3 (create success via `InMemoryCardStore` — `deckIds` populated from `Mode.create(deckId:)`; nil deckId creates an orphan), C4 (edit success with `updatedAt` advancing and `id`/`createdAt`/`deckIds` preserved), C7 (orphan editing and delete). |
| `CardListViewModelTests.swift` | C3/C4/C5 mutation propagation, C8 strategy-independent ordering, C11 `changes` subscription, C12 empty state, plus `snapshot(forRowId:)` lookup and `delete(id:)` dispatch. Uses a `ReverseCardOrderingStub` to prove the view model does not re-sort. |
| `AllCardsViewModelTests.swift` | C3/C4/C5 mutation propagation, C6 orphan-on-last-deck-deletion (both in-memory-via-`simulateDeckDeleted` AND shared-context Core Data variants), C11, C12, B11-C (deck deletion preserves cards still attached to other decks), strategy-independence, and `snapshot(forRowId:)` / `delete(id:)`. |
| `StudySessionViewModelTests.swift` | The 11 view-model-level cases from Req 10 AC 3 of study-mode, named per design §Testing Strategy, plus supplementary state-transition-table tests (no-ops in `.frontRevealed`/`.emptyDeck`/`.completed`; `returnHome()` in `.completed`; fetch-failure path setting `loadError` via a throwing `CardStore` stub) and a protocol-dependency compile-time check. Uses `InMemoryCardStore` + either `CardCreationDateAscendingOrdering` or a test-local `FixedOrderStrategy`. No Core Data. |

## Directives

- Mark the test class `@MainActor` — the view models are main-actor isolated.
- Back the view model with an in-memory store; use `waitBriefly()` (50ms expectation) to let Combine emissions hop to the main queue before asserting.
- Shared-context tests (`C6`/`B11-C` on the Core Data side) build both the deck store and the card store against the same `container.viewContext` — that's what lets the `NSManagedObjectContextDidSave` notification drive the card store's observer.
