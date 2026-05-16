# Implementation Plan: Study Mode (P0)

## Overview

Implementation plan for the P0 study-mode feature. Tasks are TDD-ordered per D007 and D021: each production-code task is preceded by the example-based XCTest that describes its behavior. Tests are written first and made to fail, then the implementation is added to make them pass — matching the pattern in `.kiro/specs/deck-management/tasks.md` and `.kiro/specs/card-management/tasks.md`.

Traces to:
- `.kiro/specs/study-mode/requirements.md` — requirements (Req IDs)
- `.kiro/specs/study-mode/design.md` — architecture, state-transition table, file layout, Testing Strategy

Conventions:
- Test framework: XCTest only (tech.md, D021). Unit tests live in `HanaHouTests/`.
- Each test task names the file to create and the Req IDs it traces to; view-model tests additionally enumerate the 12 test cases from Req 10 AC 3.
- All tasks are required (no optional `*` sub-tasks); status is tracked per numbered task via the `taskStatus` tool.
- Every new Swift source file must be added to the `HanaHou` app target; every new Swift test file must be added to the `HanaHouTests` target. Target-membership updates are called out inline, matching the card-management precedent.
- Study mode introduces **no Core Data schema change** (Req 9 AC 2). The v3 model from card-management is consumed unchanged.
- Study mode introduces **no new persistence protocol, no new ordering protocol, and no new error type** (design §Components and Interfaces, §Data Models). It consumes `CardStore` and `CardOrderingStrategy` as dependencies (Req 9 AC 4, 9 AC 5).

## Tasks

- [x] 1. Foundations: `SelfGrade` enum and `StudySession` value type (tests first for `SelfGrade`)
  - [x] 1.1 Write `HanaHouTests/Domain/SelfGradeTests.swift` with the header format from design §Testing Strategy ("Feature: study-mode / Covers requirements: 4.1, 4.6, 9.6, 10.2, 10.3.12"); tests must fail because `SelfGrade` does not yet exist
    - `test_selfGrade_hasThreeCasesWithDistinctNonEmptyLabels` — assert `SelfGrade.allCases.count == 3`, that each `label` is non-empty, and that the three labels are pairwise distinct (Req 10 AC 3.12, Req 9 AC 6)
    - Assert each expected case exists and has its D036 label: `.know → "I know it"`, `.close → "I'm close"`, `.noIdea → "No idea"` (Req 4 AC 1 per D036)
    - Assert `SelfGrade` conforms to `Equatable` and `CaseIterable` (Req 9 AC 6) and exposes a stable `String` raw value (design §Data Models — rationale for future P1 `StudyEvent` persistence per D039)
    - Add file to the `HanaHouTests` target in `HanaHou.xcodeproj/project.pbxproj`
    - _Requirements: 4.1, 4.6, 9.6, 10.2, 10.3.12; decisions D008, D036, D039_
  - [x] 1.2 Implement `HanaHou/Models/SelfGrade.swift` to satisfy 1.1 — per design §Data Models
    - `enum SelfGrade: String, Equatable, CaseIterable { case know; case close; case noIdea }` with a `var label: String` switch returning the D036 display strings from a single point of change
    - Semantic case names (`.know`, `.close`, `.noIdea`); `label` is the display string; raw value is included for future stable on-disk identity (D039)
    - Add file to the `HanaHou` app target
    - _Requirements: 4.1, 4.6, 9.6; decisions D008, D036_
  - [x] 1.3 Create `HanaHou/Models/StudySession.swift` with the `StudySession` value type and nested `Phase` enum plus the `CurrentCardView` projection — per design §Data Models
    - `struct StudySession: Equatable { let deckId: UUID; let cards: [CardSnapshot]; var position: Int; var phase: Phase; var grades: [UUID: SelfGrade] }`
    - `enum Phase: Equatable { case frontRevealed, backRevealed, completed, emptyDeck }`
    - `struct CurrentCardView: Equatable { let frontText: String; let backText: String; let position: Int; let total: Int; let phase: StudySession.Phase }`
    - Pure value-type scaffolding — no tests required; behavior is exercised via `StudySessionViewModel` tests
    - Add file to the `HanaHou` app target
    - _Requirements: 9.1; design §Data Models_

- [x] 2. `StudySessionViewModel` (the Req 9 "Study_Manager") — tests first
  - [x] 2.1 Write `HanaHouTests/ViewModels/StudySessionViewModelTests.swift` with the header format from design §Testing Strategy ("Feature: study-mode / Covers requirements: 1.x, 2.x, 3.x, 4.x, 5.x, 6.x, 7.x, 9.x / Test cases from Req 10 AC 3: 1–11"); tests must fail because `StudySessionViewModel` does not yet exist
    - Include the `FixedOrderStrategy` test-local stub shown in design §Testing Strategy, and use `InMemoryCardStore` + `CardCreationDateAscendingOrdering` for the deterministic cases (Req 10 AC 1, 9 AC 4, 9 AC 5)
    - Enumerate the 11 `StudySessionViewModel`-level test cases from Req 10 AC 3, one per XCTest method, using the exact names proposed in design §Testing Strategy:
      - [x] 2.1.1 `test_init_withEmptyDeck_entersEmptyDeckPhase_andExposesNoCurrentCard` — Req 10 AC 3.1, Req 1 AC 9, Req 1 AC 10
      - [x] 2.1.2 `test_init_withNonEmptyDeck_entersFrontRevealedAtPositionZero` — Req 10 AC 3.2, Req 1 AC 6, Req 1 AC 7
      - [x] 2.1.3 `test_init_appliesOrderingStrategyToFetchedCards` — Req 10 AC 3.3, Req 1 AC 3, Req 9 AC 3, Req 9 AC 5; uses `FixedOrderStrategy`
      - [x] 2.1.4 `test_init_withP0Strategy_ordersByCreatedAtAscWithIdTiebreaker` — Req 10 AC 3.4, Req 1 AC 4; exercises distinct and tied `createdAt` fixtures against the real `CardCreationDateAscendingOrdering` per D032
      - [x] 2.1.5 `test_flip_inFrontRevealed_transitionsToBackRevealed_sameCard` — Req 10 AC 3.5, Req 3 AC 1, Req 3 AC 2
      - [x] 2.1.6 `test_flip_inBackRevealed_isNoOp` — Req 10 AC 3.6, Req 3 AC 5
      - [x] 2.1.7 `test_grade_recordsGradeForCurrentCardId` — Req 10 AC 3.7, Req 4 AC 3, Req 4 AC 5
      - [x] 2.1.8 `test_grade_notLastPosition_advancesAndReturnsToFrontRevealed` — Req 10 AC 3.8, Req 5 AC 1, Req 4 AC 4
      - [x] 2.1.9 `test_grade_atLastPosition_transitionsToCompleted` — Req 10 AC 3.9, Req 5 AC 2
      - [x] 2.1.10 `test_orderedSequence_isSnapshotAtStart_notAffectedByStoreMutations` — Req 10 AC 3.10, Req 1 AC 8; mutate the `InMemoryCardStore` after `init` and assert `session.cards` is unchanged
      - [x] 2.1.11 `test_exit_discardsInMemoryState_andPersistsNothing` — Req 10 AC 3.11, Req 7 AC 2, Req 7 AC 4; assert no store writes occur and the view model's session is cleared
    - Add the supplementary transition-table tests from design §Testing Strategy to pin the state machine fully: `test_grade_inFrontRevealed_isNoOp`, `test_returnHome_inCompleted_discardsState`, `test_init_fetchFailure_rendersEmptyDeckPhase_andSetsLoadError` (uses a throwing `CardStore` stub)
    - Each test uses a fresh `InMemoryCardStore`; none touches Core Data (Req 10 AC 1)
    - Add file to the `HanaHouTests` target
    - _Requirements: 1.1–1.10, 2.1–2.5, 3.1–3.5, 4.1–4.6, 5.1–5.4, 6.1–6.6, 7.1–7.4, 9.1–9.6, 10.1, 10.3.1–10.3.11; decisions D007, D021, D032, D036_
  - [x] 2.2 Implement `HanaHou/ViewModels/StudySessionViewModel.swift` satisfying 2.1 — per design §Components and Interfaces and the state-transition table
    - `@MainActor`, `ObservableObject`
    - `@Published private(set) var session: StudySession`, `@Published private(set) var currentCard: CurrentCardView?`, `@Published var loadError: Error?`
    - `init(deckId: UUID, store: CardStore, strategy: CardOrderingStrategy)` — calls `try store.fetchInDeck(deckId: deckId)` and applies `strategy.order(_:)` (Req 9 AC 3); on success builds the `StudySession` with `position = 0` and `phase = cards.isEmpty ? .emptyDeck : .frontRevealed` (Req 1 AC 6, 1 AC 9); on failure builds an `.emptyDeck` session and sets `loadError` (design §Error Handling)
    - `func flip()` — `.frontRevealed → .backRevealed`; no-op in every other phase (Req 3 AC 1, 3 AC 5)
    - `func grade(_ grade: SelfGrade)` — writes `grades[currentCardId] = grade` then advances (Req 4 AC 3, 4 AC 4); no-op in `.frontRevealed`, `.emptyDeck`, `.completed` (per the transition table)
    - `func exit()` — clears session state (Req 7 AC 2); view pops one level via callback (Req 7 AC 3)
    - `func returnHome()` — clears session state (Req 6 AC 6); view pops to root via callback (Req 6 AC 5)
    - Depends on `CardStore` and `CardOrderingStrategy` protocols only (Req 9 AC 4, 9 AC 5) — no concrete types
    - Does **not** subscribe to `CardStore.changes` (Req 1 AC 8); session is a snapshot at start
    - Private `refreshCurrentCard()` helper keeps `currentCard` in sync after every intent mutation
    - Add file to the `HanaHou` app target
    - _Requirements: 1.1–1.10, 2.1–2.5, 3.1–3.5, 4.1–4.6, 5.1–5.4, 6.1–6.6, 7.1–7.4, 9.1–9.6_

- [x] 3. Checkpoint — ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Views, navigation, and entry point
  - Note: per D021 and the deck/card-management precedent, SwiftUI view bodies are not unit-tested in isolation. Wiring-level smoke assertions are consolidated in task 4.5.
  - [x] 4.1 Extend `HanaHou/Views/DeckManagementRootView.swift`'s `DeckManagementRoute` enum with `case study(DeckSnapshot)` — per design §Components and Interfaces / "Navigation integration"
    - Extend `destination(for:)` with the `.study(let deck)` arm: constructs `StudyView(deck: deck, viewModel: StudySessionViewModel(deckId: deck.id, store: cardStore, strategy: cardStrategy), onExit: { path.removeLast() }, onReturnHome: { path.removeLast(path.count) })`
    - No change to `DeckManagementRootView`'s init signature (design §Composition Root Changes — "needs **no change**"); `cardStore` and `cardStrategy` already flow through
    - _Requirements: 1.1, 8.1; design §Composition Root Changes_
  - [x] 4.2 Extend `HanaHou/Views/CardListView.swift` to add the "Study" toolbar entry point per design §Components and Interfaces / "Navigation integration"
    - Add a `ToolbarItem(placement: .topBarTrailing)` button labeled `Label("Study", systemImage: "play.fill")` that calls `onNavigate(.study(deck))`
    - Accessibility identifier `"StudyButton"` (referenced by the smoke test in 4.5)
    - `.disabled(viewModel.items.isEmpty)` — UI-level nicety; the view model remains correct for empty decks via the `.emptyDeck` phase (design note)
    - No change to `AllCardsView` — the All Cards surface deliberately has no study affordance in P0 (Req 8 AC 2 per D041 — deferred, not excluded)
    - _Requirements: 1.1, 8.2; decisions D041_
  - [x] 4.3 Create `HanaHou/Views/StudyView.swift` per design §Components and Interfaces / "StudyView (SwiftUI)"
    - Parameters: `let deck: DeckSnapshot`, `@StateObject var viewModel: StudySessionViewModel`, `let onExit: () -> Void`, `let onReturnHome: () -> Void`
    - Body switches on `viewModel.session.phase`:
      - `.frontRevealed`: render progress label ("\(position + 1) of \(total)", Req 2 AC 5), `currentCard.frontText` (Req 2 AC 1), a prominent "Show Back" button calling `viewModel.flip()` (Req 2 AC 4); do **not** render back text (Req 2 AC 2) or grade buttons (Req 2 AC 3)
      - `.backRevealed`: render progress label, both front and back text (Req 3 AC 2), three grade buttons built from `SelfGrade.allCases` with labels from `SelfGrade.label` calling `viewModel.grade(_:)` (Req 3 AC 3, 4 AC 1, 4 AC 2); do **not** render the "Show Back" affordance (Req 3 AC 4)
      - `.completed`: render `StudyCompletionView(deckName: deck.name, onReturnHome: { viewModel.returnHome(); onReturnHome() })` (Req 6 AC 1)
      - `.emptyDeck`: render empty-state message ("This deck has no cards to study yet.") and a "Back to deck" button calling `onExit()` (Req 1 AC 10)
    - Toolbar `topBarTrailing` "Exit" button — visible in `.frontRevealed` and `.backRevealed` only; accessibility identifier `"StudyExitButton"`; calls `viewModel.exit()` then `onExit()` (Req 7 AC 1, 7 AC 2, 7 AC 3)
    - `.alert` bound to `viewModel.loadError` with an OK action that clears the error and calls `onExit()` (design §Error Handling)
    - Inherits the global Info.plist portrait lock (D014/D028) — no study-side orientation override (Req 8 AC 3, 8 AC 4)
    - Add file to the `HanaHou` app target
    - _Requirements: 1.7, 1.10, 2.1–2.5, 3.2–3.4, 4.1, 4.2, 6.1, 7.1, 7.3, 8.1, 8.3, 8.4_
  - [x] 4.4 Create `HanaHou/Views/StudyCompletionView.swift` per design §Components and Interfaces / "StudyCompletionView (SwiftUI)"
    - Parameters: `let deckName: String`, `let onReturnHome: () -> Void`
    - Body renders "Finished studying \(deckName)." (Req 6 AC 2) and a single `.borderedProminent` "Return Home" button calling `onReturnHome()` (Req 6 AC 3); accessibility identifier `"StudyReturnHomeButton"`
    - Body contains **no** statistics, grade counts, or history (Req 6 AC 4 per D010)
    - Stateless; holds no reference to the view model
    - Add file to the `HanaHou` app target
    - _Requirements: 6.2, 6.3, 6.4; decisions D010_
  - [x] 4.5 Extend `HanaHouTests/Views/DeckManagementSmokeTests.swift` with study-side smoke tests — per design §Testing Strategy / "Smoke tests (view wiring)"; do not create a new test file (mirrors the card-management precedent in task 7.8 of `.kiro/specs/card-management/tasks.md`)
    - `test_study_routeResolvesToStudyView` — construct `DeckManagementRootView(...)`, push `.study(deck)`, force-evaluate the body; smoke-level check that no runtime assertion fires and the destination compiles (Req 8 AC 1)
    - `test_cardListView_exposesStudyButton` — `CardListView`'s accessibility tree contains `StudyButton` when the deck has at least one card; check that the handler routes `.study(deck)` via a captured `onNavigate` closure (Req 1 AC 1, Req 8 AC 2)
    - `test_studyCompletionView_rendersDeckNameAndReturnHomeButton` — static snapshot of `StudyCompletionView(deckName: "Japanese", onReturnHome: {})`: body contains the deck name substring and the `StudyReturnHomeButton` identifier (Req 6 AC 2, 6 AC 3)
    - Each added test case carries the behavior/requirement annotations in its header comment, same style as the existing cases in this file
    - _Requirements: 1.1, 6.2, 6.3, 8.1, 8.2_

- [x] 5. Xcode project membership
  - [x] 5.1 Add every new Swift file to the correct target in `HanaHou.xcodeproj/project.pbxproj`
    - App target (`HanaHou`): `HanaHou/Models/SelfGrade.swift`, `HanaHou/Models/StudySession.swift`, `HanaHou/ViewModels/StudySessionViewModel.swift`, `HanaHou/Views/StudyView.swift`, `HanaHou/Views/StudyCompletionView.swift`
    - Test target (`HanaHouTests`): `HanaHouTests/Domain/SelfGradeTests.swift`, `HanaHouTests/ViewModels/StudySessionViewModelTests.swift`
    - The existing modified files (`DeckManagementRootView.swift`, `CardListView.swift`, `DeckManagementSmokeTests.swift`) already have the correct memberships — confirm no changes are needed there
    - No Core Data model change (Req 9 AC 2) — no `.xcdatamodeld` edits
    - _Requirements: (project convention; follows card-management precedent)_

- [x] 6. Final checkpoint — build and run the full test suite
  - Build the app target (⌘B equivalent) and run all unit tests (⌘U equivalent); confirm the suite is green and that the new `SelfGradeTests` and `StudySessionViewModelTests` both pass
  - Manually exercise the study flow on an iPad simulator end-to-end: open a deck with at least one card → tap Study → flip → grade through every card → land on the completion screen → return home; also exercise the exit affordance mid-session and the empty-deck path (open a deck with zero cards → tap Study → empty-state)
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Wrap-up: AGENTS.md updates and session log
  - [x] 7.1 Update/create `AGENTS.md` in each directory whose contents changed (per D005), per design §File Layout / "AGENTS.md updates required"
    - `HanaHou/Models/AGENTS.md` — add entries for `SelfGrade.swift` and `StudySession.swift`
    - `HanaHou/ViewModels/AGENTS.md` — add entry for `StudySessionViewModel.swift`
    - `HanaHou/Views/AGENTS.md` — add entries for `StudyView.swift` and `StudyCompletionView.swift`; note the `CardListView` and `DeckManagementRootView` modifications (new `.study` route, new Study toolbar button)
    - `HanaHouTests/Domain/AGENTS.md` — add entry for `SelfGradeTests.swift`
    - `HanaHouTests/ViewModels/AGENTS.md` — add entry for `StudySessionViewModelTests.swift`
    - `HanaHouTests/Views/AGENTS.md` — note the extended smoke tests
    - No changes to `HanaHou/Domain/AGENTS.md` or `HanaHou/Persistence/AGENTS.md` — those directories are unchanged
    - _Requirements: (project convention D005)_
  - [x] 7.2 Add a new session log file under `docs/sessions/` (filename format matches the existing convention: `YYYY-MM-DD-study-mode.md`); include a brief summary of what was built, which tasks were completed, and links to `.kiro/specs/study-mode/requirements.md`, `.kiro/specs/study-mode/design.md`, and `.kiro/specs/study-mode/tasks.md`
    - Keep the entry concise (1–2 paragraphs plus a short commits/decisions list), matching the tone of `docs/sessions/2026-05-02-card-management.md`
    - Reference decisions D036, D039, D041 in the summary
    - _Requirements: (project convention; `docs/sessions/AGENTS.md`)_

## Notes

- **No Core Data changes.** Study mode is entirely in-memory in P0 (Req 9 AC 2). `StudyEvent` persistence is deferred to P1 per D039; it will be additive (new entity, new store, optional write from `StudySessionViewModel`) and will not touch the state machine built here.
- **No new protocols.** `CardStore` and `CardOrderingStrategy` are reused as-is (D032). The ordering strategy is injected so the P1 shuffle variant can replace `CardCreationDateAscendingOrdering` without changes to `StudyView` or `StudySessionViewModel` (Req 1 AC 5).
- **`SelfGrade` is the single point of change for the self-grade categories** (D008, D036). All display strings flow through `SelfGrade.label`; case names are semantic and a `String` raw value is present for future P1 stable on-disk identity per D039. A future "Test Mode" with outcome-oriented labels touches only this file.
- **All Cards has no study affordance in P0** (Req 8 AC 2). This is deferred, not excluded, per D041 — study from All Cards (and from any scope larger than one deck) is a P1+ feature that will need a scope concept and a different entry point. No code paths in this plan reach for it.
- **View-body unit tests are intentionally absent.** The card-management precedent consolidates wiring-level smoke assertions in `DeckManagementSmokeTests.swift` (task 4.5 here); algorithmic logic lives in the view model and is covered by `StudySessionViewModelTests` (task 2.1).
- **`HanaHouUITests/`** is not exercised in P0 (same as deck-management and card-management). Existing UI tests should continue to compile; if they fail to build against the added `.study` route, fix minimally — do not add new UI tests.
- **The Core Data model is untouched** (Req 9 AC 2). The `HanaHou 3.xcdatamodel` from card-management remains current; no `.xccurrentversion` edit, no new entity, no attribute change.
