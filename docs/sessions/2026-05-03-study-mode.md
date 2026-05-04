# Session: 2026-05-03 — Study Mode (P0)

## Summary

Spec and implementation session for Study Mode, the third and final P0 feature. Users can now open a deck, tap a Study button, flip cards front-to-back, self-grade with three confidence-oriented categories (D036 — "I know it", "I'm close", "No idea"), advance sequentially through the deck, and land on a completion screen that returns them home. Followed the existing four-layer architecture unchanged and reused the existing `CardStore` and `CardOrderingStrategy` protocols — study mode added no new Core Data entity, no new persistence abstraction, and no new ordering protocol. Study state is entirely in-memory; `StudyEvent` persistence is deferred to P1 per D039 (not P2).

Spec links:
- [`requirements.md`](../../.kiro/specs/study-mode/requirements.md)
- [`design.md`](../../.kiro/specs/study-mode/design.md)
- [`tasks.md`](../../.kiro/specs/study-mode/tasks.md)

## What was built

### Value types (Models)
`SelfGrade` enum with semantic cases (`.know`, `.close`, `.noIdea`), a single `label` computed property holding the D036 display strings, and a `String` raw value for future P1 stable on-disk identity (D039). `StudySession` struct with `deckId`, immutable `cards: [CardSnapshot]` (`let` — the start-time snapshot guarantee of Req 1 AC 8 is compile-time-enforced), `position`, `phase`, and `grades: [UUID: SelfGrade]`, plus a nested `Phase` enum (`.frontRevealed`, `.backRevealed`, `.completed`, `.emptyDeck`). `CurrentCardView` projection pre-computes the view's read model to keep `StudyView` thin.

### View model
`StudySessionViewModel` — the Req 9 "Study_Manager". `@MainActor`, `ObservableObject`. Depends only on the `CardStore` and `CardOrderingStrategy` protocols (Req 9 AC 4, 9 AC 5) — never on concrete types. Fetches + orders in `init`, then never touches the store again; does not subscribe to `CardStore.changes`. Intents: `flip()`, `grade(_:)`, `exit()`, `returnHome()` — every (phase × intent) cell of the design's transition table has a test pinning its behavior.

### Views and navigation
`StudyView` is a single view that switches its body on `session.phase`. The `.frontRevealed` branch shows a progress label, front text, and a "Show Back" button; `.backRevealed` adds back text and three grade buttons sourced from `SelfGrade.allCases` with labels from `SelfGrade.label`; `.completed` inlines `StudyCompletionView`; `.emptyDeck` shows an empty-state message and a "Back to deck" button. Exit toolbar button visible only during active phases. `StudyCompletionView` is stateless — just the deck name and a "Return Home" button, no statistics (per D010). Navigation extends `DeckManagementRoute` with `case study(DeckSnapshot)` and wires the destination through `DeckManagementRootView`. `CardListView` gained a "Study" toolbar button; `AllCardsView` deliberately did not (Req 8 AC 2 per D041 — deferred from P0, not permanently excluded).

### Tests (all example-based XCTest per D021)
- `SelfGradeTests` — 8 cases: exactly three cases, distinct non-empty labels, D036 label verbatim, `Equatable`/`CaseIterable` conformance, stable `String` raw value
- `StudySessionViewModelTests` — 18 cases: the 11 view-model-level cases from Req 10 AC 3 (1–11) with the exact names from design §Testing Strategy, plus seven supplementary transition-table tests (`.frontRevealed` grading no-op, `.backRevealed`/`.emptyDeck`/`.completed` flip no-ops, `.completed` grade no-op, `returnHome()` in `.completed`, fetch-failure path via a throwing `CardStore` stub) and a compile-time protocol-dependency check. Uses `InMemoryCardStore` and a test-local `FixedOrderStrategy` where the test needs to prove the view model applies the strategy's output verbatim. No Core Data.
- Extended `DeckManagementSmokeTests` with four study-side smoke cases: `.study(deck)` route compiles and resolves, Study toolbar button identifier contract, `StudyCompletionView` deck-name + `onReturnHome` callback semantics, and view-model-level proof that grading every card transitions to `.completed`.

### Incidental fix: Swift 6 / iOS 26 isolated-deinit workaround
While running the initial view-model tests, every test in the suite — both new and existing (`CardListViewModelTests` included) — crashed on teardown with `BUG_IN_CLIENT_OF_LIBMALLOC_POINTER_BEING_FREED_WAS_NOT_ALLOCATED` inside `swift_task_deinitOnExecutorImpl`. Root cause: under Xcode 26.4.1 / iOS 26.1 simulator, the Swift 6 compiler-synthesized isolated-deinit path traps when a `@MainActor` reference type is deallocated synchronously from the main thread (e.g., at the end of a test method on an `@MainActor XCTestCase`). Fix: added an explicit `nonisolated deinit {}` to every `@MainActor`-isolated class that was crashing — six files total (`StudySessionViewModel`, plus the five pre-existing view models and `InMemoryCardStore`/`InMemoryDeckStore`). The empty `nonisolated deinit` sidesteps the task-executor deinit hop. All view models hold no resources that need main-actor cleanup, so the fix is safe. After the fix, the full 229-unit-test suite passes cleanly on Xcode 26.

## Decisions recorded

D036, D039, D041 (see [`docs/decisions.md`](../decisions.md)):
- D036: Self-grade labels resolved to Option A — "I know it" / "I'm close" / "No idea". `SelfGrade` is the single point of change per D008; semantic case names + `label` property + `String` raw value keep the labels swappable for a future "Test Mode".
- D039: `StudyEvent` persistence moved from P2 to P1 (roadmap restructured). P0 architecture unchanged — study state remains ephemeral; the future P1 entity will be additive. SRS (P2) will consume the P1 data.
- D041: Studying from the All Cards view is deferred from P0, not permanently excluded. P0 reaches study mode only from the per-Deck Card list; cross-deck study is a natural extension for a future priority once a scope concept exists.

## Files changed (high level)

**Added:** 2 Models (`SelfGrade.swift`, `StudySession.swift`), 1 ViewModel (`StudySessionViewModel.swift`), 2 Views (`StudyView.swift`, `StudyCompletionView.swift`), 2 Tests (`SelfGradeTests.swift`, `StudySessionViewModelTests.swift`), 1 session log, 3 decision entries (D036/D039/D041).
**Modified:** `HanaHou/Views/DeckManagementRootView.swift` (new `.study` route), `HanaHou/Views/CardListView.swift` (Study toolbar button), `HanaHouTests/Views/DeckManagementSmokeTests.swift` (four study smoke tests), `.kiro/specs/study-mode/requirements.md`/`design.md` (D036/D039/D041 references, Open Question resolution), `.kiro/specs/study-mode/tasks.md` (status marks only), and six `AGENTS.md` files under `HanaHou/` and `HanaHouTests/`. Also the Swift 6 deinit-workaround touches to `CardListViewModel`, `AllCardsViewModel`, `DeckListViewModel`, `CardEditorViewModel`, `DeckEditorViewModel`, `InMemoryCardStore`, `InMemoryDeckStore` — one-line additions each.
**Deleted:** None.

## Test results

Full unit test suite: **229 passed, 0 failed, 0 skipped** on iPad (A16) simulator, iOS 26.1.

## Next session

- Open the project in Xcode and manually exercise the study flow on an iPad simulator: open a deck → tap Study → flip → grade through every card → completion screen → return home; separately exercise the exit affordance mid-session and the empty-deck path (open an empty deck → tap Study → empty state; or start a session and pop mid-flow)
- Verify the Swift 6 / iOS 26 isolated-deinit workaround on a future Xcode release — if Apple fixes the underlying runtime bug, the `nonisolated deinit {}` placeholders can be removed
- P0 feature set is complete. Next priority tier is P1 (study persistence + UX polish — see `docs/roadmap.md`), starting with `StudyEvent` persistence per D039

