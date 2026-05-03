# Session: 2026-05-02 — Card Management (P0)

## Summary

Spec and implementation session for Card Management, the second P0 feature. Replaced the `AllCardsPlaceholderView` with real card CRUD: creating, viewing, editing, and deleting Cards within a Deck plus an All Cards view that surfaces every Card regardless of deck membership — including orphans whose last deck was deleted. Followed the existing four-layer architecture (Models → Domain → Persistence → ViewModels → Views) and the Deck management patterns one-for-one.

Spec links:
- [`requirements.md`](../../.kiro/specs/card-management/requirements.md)
- [`design.md`](../../.kiro/specs/card-management/design.md)
- [`tasks.md`](../../.kiro/specs/card-management/tasks.md)

## What was built

### Core Data schema v3
Added `Card.updatedAt: Date` (required, static `Date()` default for lightweight migration). Created `HanaHou 3.xcdatamodel` alongside v1 and v2 and updated `.xccurrentversion`. Lightweight inferred migration populates pre-existing rows without a post-migration fixup (D030).

### Value types
`CardDraft`, `CardSnapshot` (with `deckIds: Set<UUID>` — empty set identifies orphans), `CardTextError` (distinct `.missingFront` / `.missingBack` cases), `CardRowItem` (display row with `isOrphan`).

### Domain layer
`CardTextValidator.validate(draft:)` — trims with `.whitespacesAndNewlines`, checks front before back. `CardOrderingStrategy` + `CardCreationDateAscendingOrdering` — introduced as a sibling of `DeckOrderingStrategy` rather than a generic protocol (D032).

### Persistence layer
`CardStore` protocol with `fetchAll / fetchInDeck / create / update / delete / changes`. `InMemoryCardStore` (with a test-only `simulateDeckDeleted(deckId:)` helper) and `CoreDataCardStore` (shares `container.viewContext` with `CoreDataDeckStore` so a deck deletion's `NSManagedObjectContextDidSave` triggers card-side refreshes). Update and delete on unknown id are silent no-ops that do not emit on `changes` (D033).

### View models
`CardEditorViewModel` with `Mode.create(deckId: UUID?)` and `Mode.edit(CardSnapshot)`; two independent `@Published` error channels so both messages can display concurrently. `CardListViewModel` and `AllCardsViewModel` subscribe to `store.changes` and re-query on each signal; both expose `snapshot(forRowId:)` to resolve a tapped row back to its full snapshot for navigation.

### Views and navigation
`CardListView`, `AllCardsView`, `CardEditorView` with inline validation messages and confirmation-gated delete. Extended `DeckManagementRoute` with `.cardList / .createCard / .editCard`. The `.allCards` destination now resolves to `AllCardsView` — `AllCardsPlaceholderView.swift` was deleted (D034).

### UX change: deck-row tap destination
Tapping a user-deck row in `DeckListView` now pushes `.cardList(deck)` instead of `.editDeck(deck)`. Users open a deck to see its cards; "Edit Deck" moved to a toolbar button on `CardListView` (D031).

### Composition root
`PersistenceController.makeCardStore(clock:)` uses the same `container.viewContext` as `makeDeckStore` so orphan handling works for free. `HanaHouApp` passes both stores plus the two ordering strategies into `DeckManagementRootView`.

### Tests (all example-based XCTest per D021)
- `CardTextValidatorTests` — 13 cases covering C1/C2 and whitespace trimming
- `CardOrderingStrategyTests` — 7 cases covering C8 with deterministic UUID tiebreakers
- `InMemoryCardStoreTests` — 23 cases covering C1/C2/C3/C4/C5/C9/C10 plus the `simulateDeckDeleted` helper
- `CoreDataCardStoreTests` — full parity plus C6 and B11-C via shared-context `CoreDataDeckStore` / `CoreDataCardStore`
- `CardEditorViewModelTests` — C1/C2/C3/C4/C7 plus concurrent-errors and submit-gating
- `CardListViewModelTests` — C3/C4/C5/C8/C11/C12 plus `ReverseCardOrderingStub` for strategy-independence
- `AllCardsViewModelTests` — C3/C4/C5/C6 (both in-memory and Core Data variants)/C11/C12/B11-C
- Extended `DeckManagementSmokeTests.swift` with card-side smoke cases and the new route-enum assertions

## Decisions recorded

D030 through D035 (see [`docs/decisions.md`](../decisions.md)):
- D030: Card `updatedAt` added in schema v3 with a static `Date()` default — no post-migration fixup
- D031: Tapping a user-deck row opens `CardListView` instead of `DeckEditorView`
- D032: `CardOrderingStrategy` as a sibling of `DeckOrderingStrategy`, not a generic
- D033: `CardStore.update`/`.delete` on unknown id are silent no-ops that do not emit on `changes`
- D034: `AllCardsView` replaces `AllCardsPlaceholderView`; placeholder source deleted
- D035: `CardDraft` carries text only; deck membership is a separate `deckIds` argument to `CardStore.create`

## Files changed (high level)

**Added:** 4 Models, 2 Domain, 3 Persistence, 3 ViewModels, 3 Views, 7 Tests, 1 Core Data model version (v3), 1 session log, 6 decision entries.
**Modified:** `HanaHou/Persistence.swift`, `HanaHou/HanaHouApp.swift`, `HanaHou/Views/DeckManagementRootView.swift`, `HanaHou/Views/DeckListView.swift`, `HanaHou/HanaHou.xcdatamodeld/.xccurrentversion`, `HanaHouTests/Views/DeckManagementSmokeTests.swift`, `docs/data-model.md`, all per-directory `AGENTS.md` files under `HanaHou/` and `HanaHouTests/`.
**Deleted:** `HanaHou/Views/AllCardsPlaceholderView.swift`.

## Next session

- Open the project in Xcode, run ⌘U against an iPad simulator to confirm the full suite is green, and verify the v3 migration completes cleanly against a fresh store
- Manual QA on the iPad simulator: create a card in a deck, edit it, delete it, delete a deck and confirm its cards survive in All Cards
- Consider the two open visual decisions: orphan-row badging in `AllCardsView` and deck-editor "Edit Deck" affordance placement on `CardListView` (currently a toolbar button — could also be a swipe action on the deck row)
- Begin the next P0 feature — Study Mode
