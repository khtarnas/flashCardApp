# Implementation Plan: Deck Management (P0)

## Overview

Implementation plan for the P0 deck management feature. Tasks are TDD-ordered per D007 and D021: each production-code task is preceded by the example-based XCTest that describes its behavior. Tests are written first, then made to pass.

Traces to:
- `.kiro/specs/deck-management/requirements.md` — requirements (Req IDs)
- `.kiro/specs/deck-management/design.md` — architecture, behaviors B1–B11, type signatures

Conventions:
- Test framework: XCTest only (tech.md). Unit tests live in `HanaHouTests/`.
- Behaviors B1–B11 are defined in the design document §11 (Testing Approach).
- Each test task names the file to create, the B-IDs it covers, and the Req IDs it traces to.
- Most tasks are required. Truly optional enhancements are postfixed with `*` on the checkbox (e.g., `- [ ]* 3.4 ...`).
- Task dependencies are implicit by order unless a "Blocked by" note is present.

## Tasks

- [ ] 1. Foundations: strip template, extend data model, add core types
  - [x] 1.1 Delete `Item`-specific code from `ContentView.swift` and remove the `Item` entity wire-up
    - Keep `ContentView.swift` compiling with a placeholder body; full replacement happens in task 5.1
    - _Requirements: (prep — no req)_
  - [x] 1.2 Update `HanaHou.xcdatamodeld`: remove `Item`, add `Deck` and `Card` entities with the schema and many-to-many relationship from design §3
    - Attributes per design §3: Deck{id,name,frontLanguageRaw,backLanguageRaw,createdAt,updatedAt}, Card{id,frontText,backText,createdAt}
    - Relationship: `Deck.cards` ↔ `Card.decks`, to-many on both sides, nullify on delete
    - `Deck.uniquenessConstraints = [["id"]]` only; no name constraint (per D027)
    - _Requirements: 6.1, 6.6_
  - [x] 1.3 Bump the Core Data model version: create `HanaHou 2.xcdatamodel` inside `HanaHou.xcdatamodeld`, set as current, enable lightweight migration in `PersistenceController`
    - Rationale: establish a versioned baseline for future migrations (design §3)
    - _Requirements: (supports 6.x)_
  - [-] 1.4 Create `HanaHou/Models/Language.swift` with the `Language` enum (`String, CaseIterable, Codable, Hashable`) and cases from design §3
    - Pure data declaration — no tests required per TDD judgment (D007)
    - _Requirements: 2.2, 6.1_
  - [~] 1.5 Create `HanaHou/Models/DeckSnapshot.swift` and `HanaHou/Models/DeckDraft.swift` value types matching design §3
    - Pure value-type scaffolding — no tests required
    - _Requirements: 6.1_
  - [~] 1.6 Create `HanaHou/Models/DeckListItem.swift` with the `enum DeckListItem { case allCards; case deck(DeckSnapshot) }` and nested `ID` enum from design §4
    - Pure type declaration — no tests required; behavior is exercised via `DeckListComposer` tests
    - _Requirements: 1.3, 8.5_
  - [~] 1.7 Create `HanaHou/Models/DeckNameError.swift` with `empty`, `reserved(name:)`, `duplicate(name:)` cases per design §6
    - Pure type declaration — no tests required; behavior covered by validator tests
    - _Requirements: 5.5_
  - [~] 1.8 Create `HanaHou/Persistence/DeckStore.swift` defining the `DeckStore` protocol and `DeckStoreError` per design §7
    - Protocol declaration — no tests required; tested via concrete implementations
    - _Requirements: 6.1_
  - [~] 1.9 Create `HanaHou/Models/AllCardsActionError.swift` with `enum AllCardsActionError: Error { case notAllowed }` per design §9
    - _Requirements: 4.4, 8.3, 8.4_

- [ ] 2. Domain services (tests first for each)
  - [~] 2.1 Write `HanaHouTests/Domain/DeckNameValidatorTests.swift`
    - Covers B1 (empty/whitespace rejected), B2 (reserved-name variants), B3 (duplicate including trim/case rules and edit-mode self-exclusion)
    - _Requirements: 2.4, 2.5, 2.6, 3.3, 3.4, 3.5, 5.1, 5.2, 5.3, 5.4, 5.6, 6.2, 6.3_
  - [~] 2.2 Implement `HanaHou/Domain/DeckNameValidator.swift` to satisfy 2.1
    - Pure function `(proposedName, existingDecks, editingDeckId?) -> Result<String, DeckNameError>` per design §6
    - _Requirements: 2.4, 2.5, 2.6, 3.3, 3.4, 3.5, 5.1, 5.2, 5.3, 5.4, 5.6_
  - [~] 2.3 Write `HanaHouTests/Domain/DeckOrderingStrategyTests.swift`
    - Covers B7 (creation-date ascending with `id.uuidString` tiebreaker on equal `createdAt`)
    - _Requirements: 1.6_
  - [~] 2.4 Implement `HanaHou/Domain/DeckOrderingStrategy.swift` with the protocol and `CreationDateAscendingOrdering` struct per design §5
    - _Requirements: 1.5, 1.6, 1.7_
  - [~] 2.5 Write `HanaHouTests/Domain/DeckListComposerTests.swift`
    - Covers B8 (exactly one `.allCards` at index 0, strategy-independent) and B9 (user-deck subsequence equals `strategy.order(storedDecks)`)
    - Use a stub reverse-ordering strategy alongside `CreationDateAscendingOrdering` for strategy-independence checks
    - _Requirements: 1.1, 1.3, 1.4, 1.5, 8.1_
  - [~] 2.6 Implement `HanaHou/Domain/DeckListComposer.swift` producing `[.allCards] + strategy.order(userDecks).map(.deck)` per design §4
    - _Requirements: 1.1, 1.3, 1.4, 1.5_

- [~] 3. Checkpoint — ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 4. Persistence layer
  - [~] 4.1 Write `HanaHouTests/Persistence/InMemoryDeckStoreTests.swift`
    - Exercises CRUD, change-publisher emission on mutation, validator parity (B1/B2/B3), create/edit round-trip (B5, B6) with an injectable clock
    - _Requirements: 1.8, 2.3, 2.7, 2.8, 3.2, 3.6, 5.1–5.4, 6.2, 6.3, 6.4, 6.5, 6.7_
  - [~] 4.2 Implement `HanaHou/Persistence/InMemoryDeckStore.swift` per design §11 (test double usable as a real store for view-model tests)
    - Emits on a `PassthroughSubject<Void, Never>` after each mutation
    - Re-runs `DeckNameValidator` inside `create`/`update` to match `CoreDataDeckStore` semantics
    - Injectable `clock: () -> Date` for deterministic `createdAt`/`updatedAt`
    - _Requirements: 1.8, 2.3, 2.7, 2.8, 3.2, 3.6, 6.2, 6.3, 6.4, 6.5, 6.7_
  - [~] 4.3 Write `HanaHouTests/Persistence/CoreDataDeckStoreTests.swift`
    - Covers validator parity (B1, B2, B3), create round-trip (B5), edit round-trip (B6), and delete semantics (B11 — detach cards, keep other decks intact)
    - Uses an in-memory Core Data stack (`NSInMemoryStoreType` or `/dev/null` URL per existing `PersistenceController(inMemory:)` pattern)
    - _Requirements: 2.3, 2.5, 2.6, 2.7, 2.8, 3.2, 3.4, 3.5, 3.6, 4.2, 4.3, 5.2, 5.3, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_
  - [~] 4.4 Implement `HanaHou/Persistence/CoreDataDeckStore.swift` satisfying 4.3
    - `fetchAll`, `create`, `update`, `delete` all `throws`; `changes` publisher emits on `NSManagedObjectContextDidSave`
    - `DeckStoreError.persistenceFailed(underlying:)` on save failure, with `context.rollback()` before rethrow
    - Re-runs `DeckNameValidator` against a fresh fetch inside `perform` before save (defense-in-depth per design §6)
    - _Requirements: 4.2, 4.3, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_
  - [~] 4.5 Refactor `HanaHou/Persistence.swift`
    - Remove `Item` references; remove `fatalError` on save/load paths in favor of a `throws` API surface that can vend a `CoreDataDeckStore`
    - Keep `PersistenceController(inMemory:)` usable for tests
    - _Requirements: (infrastructure; supports 6.x)_

- [ ] 5. View models
  - [~] 5.1 Write `HanaHouTests/ViewModels/DeckEditorViewModelTests.swift`
    - Covers B1 (empty), B2 (reserved), B3 (duplicate including edit self-exclusion), B4 (three error messages distinct), B5 (create success via `InMemoryDeckStore`), B6 (edit success with `updatedAt` advancing via injected clock)
    - _Requirements: 2.1–2.8, 3.1–3.6, 5.1–5.6_
  - [~] 5.2 Implement `HanaHou/ViewModels/DeckEditorViewModel.swift` satisfying 5.1
    - `Mode { case create; case edit(DeckSnapshot) }`, `@Published` fields for name/front/back, `@Published var nameError: DeckNameError?`, submit gated on `nameError == nil`
    - Rename/delete attempts against `.allCards` produce `AllCardsActionError.notAllowed` (defense-in-depth per design §4)
    - _Requirements: 2.1–2.8, 3.1–3.6, 5.1–5.6, 8.3_
  - [~] 5.3 Write `HanaHouTests/ViewModels/DeckListViewModelTests.swift`
    - Covers B8 (exactly one `.allCards` at index 0), B9 (user-deck subsequence = strategy output), B10 (create/update/delete propagate to `items` via the change publisher)
    - Uses `InMemoryDeckStore` + a stub strategy
    - _Requirements: 1.1, 1.3, 1.4, 1.5, 1.8, 8.1_
  - [~] 5.4 Implement `HanaHou/ViewModels/DeckListViewModel.swift` satisfying 5.3
    - `@StateObject`-friendly `ObservableObject, @MainActor`, subscribes to `store.changes`, re-runs `DeckListComposer` on each signal
    - _Requirements: 1.1, 1.3, 1.4, 1.5, 1.8, 8.1_

- [~] 6. Checkpoint — ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 7. Views and navigation
  - Note: P0 does not unit-test SwiftUI view bodies (per design §10 testability table). Smoke tests for non-algorithmic items are grouped into task 7.7.
  - [~] 7.1 Create `HanaHou/Views/DeckManagementRootView.swift` hosting the `NavigationStack` and owning `DeckListViewModel` as `@StateObject`
    - _Requirements: 7.1_
  - [~] 7.2 Create `HanaHou/Views/DeckListView.swift`
    - Renders `DeckListItem`s; `.allCards` row non-swipable with `square.stack.3d.up` icon and "All Cards" label; user-deck rows show name + "Front → Back" languages with swipe-to-delete
    - Empty state text "No decks yet. Tap + to create one." (All Cards still visible per Req 8.1)
    - Toolbar "+" pushes `DeckEditorView(.create)`; tapping a user-deck row opens edit; tapping `.allCards` pushes `AllCardsPlaceholderView`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.8, 4.1, 8.1, 8.2_
  - [~] 7.3 Create `HanaHou/Views/DeckEditorView.swift`
    - Two modes (create / edit). Fields: name `TextField`, front `Picker<Language>`, back `Picker<Language>`. Inline `nameError` message under the name field. Save disabled when invalid; Save pops stack on success; Cancel pops stack
    - Edit mode pre-populates from the target `DeckSnapshot`
    - _Requirements: 2.1, 2.2, 3.1, 5.5_
  - [~] 7.4 Create `HanaHou/Views/DeleteConfirmationDialog.swift` (or inline `.confirmationDialog` modifier) with copy "Delete \"\(name)\"? Cards in this deck will be kept and remain visible in All Cards."
    - _Requirements: 4.1, 4.2, 4.3_
  - [~] 7.5 Create `HanaHou/Views/AllCardsPlaceholderView.swift` with copy "All Cards view — coming in the card-management spec."
    - _Requirements: 8.2_
  - [~] 7.6 Wire view models to views in `DeckManagementRootView`: inject `DeckStore` and `DeckOrderingStrategy`, construct `DeckListViewModel`, route `DeckEditorView` via `NavigationStack` path
    - _Requirements: 1.7, 1.8, 7.1_
  - [~] 7.7 Write `HanaHouTests/Views/DeckManagementSmokeTests.swift` — example-based smoke tests for non-algorithmic items
    - NavigationStack presence on `DeckManagementRootView` (Req 7.1)
    - `DeckEditorViewModel` exposes bindable name / front / back fields (Req 2.1, 3.1)
    - Editor in edit mode is pre-populated with the target deck's values (Req 3.1)
    - Attempting rename on `.allCards` returns `AllCardsActionError.notAllowed` (Req 8.3)
    - Attempting delete on `.allCards` returns `AllCardsActionError.notAllowed` (Req 4.4, 8.4)
    - `DeckListItem.deck(_)` exposes name, front language, back language (Req 1.2)
    - A `Card` associated with two `Deck`s is reachable from both after one deck is deleted (Req 6.6, 4.3) — drives B11 at the view-model boundary
    - _Requirements: 1.2, 2.1, 3.1, 4.3, 4.4, 6.6, 7.1, 8.3, 8.4_

- [ ] 8. Orientation lock
  - [~] 8.1 Write `HanaHouTests/Configuration/InfoPlistOrientationTests.swift`
    - Reads the app bundle's `UISupportedInterfaceOrientations~ipad` (or falls back to `UISupportedInterfaceOrientations`) and asserts the configured values equal exactly `["UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown"]`
    - _Requirements: 7.2, 7.3, 7.4, 7.5_
  - [~] 8.2 Set `UISupportedInterfaceOrientations~ipad` in the app target's Info.plist to `["UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown"]`
    - Single point of change per D028 / design §8; no per-view overrides
    - _Requirements: 7.2, 7.3, 7.4, 7.5_

- [ ] 9. Wire-up and documentation
  - [~] 9.1 Update `HanaHou/HanaHouApp.swift` to host `DeckManagementRootView`
    - Construct `CoreDataDeckStore` and `CreationDateAscendingOrdering` at the composition root; inject both into `DeckListViewModel`
    - Remove the `ContentView()` reference and the template `managedObjectContext` wiring path (view models own store access now)
    - _Requirements: 1.7, 7.1_
  - [~] 9.2 Delete `HanaHou/ContentView.swift` once `DeckManagementRootView` is wired
    - Blocked by: 9.1
    - _Requirements: (cleanup)_
  - [~] 9.3 Add/update `AGENTS.md` in each new directory per D005
    - `HanaHou/Models/AGENTS.md`, `HanaHou/Domain/AGENTS.md`, `HanaHou/ViewModels/AGENTS.md`, `HanaHou/Views/AGENTS.md`, `HanaHou/Persistence/AGENTS.md`
    - Also update `HanaHou/AGENTS.md` and the corresponding `HanaHouTests/` subdirectory `AGENTS.md` files (Domain, Persistence, ViewModels, Views, Configuration)
    - _Requirements: (project convention D005)_
  - [~] 9.4 Append three new decisions to `docs/decisions.md` per design §12 "Open Design Decisions"
    - "All Cards represented as synthetic view-model item, not a stored Deck row"
    - "Name uniqueness enforced in code (validator + store), not via Core Data `uniquenessConstraints`"
    - "Orientation lock lives in Info.plist as the single point of change"
    - Note: D026, D027, D028 already exist in `docs/decisions.md` covering these three topics — reconcile by updating/merging rather than duplicating if the existing entries already suffice
    - _Requirements: (project convention)_
  - [~] 9.5 Update `docs/p0.md`: replace the "All Cards is a system concept, not a regular Deck entity (implementation TBD in mini-design)" line with a reference to the resolved design decision (D026 / design §4)
    - _Requirements: (docs alignment)_

- [~] 10. Final checkpoint — build and run the full test suite
  - Build the app target (⌘B equivalent) and run all unit tests (⌘U equivalent); confirm the suite is green
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- The view layer has no unit-test sub-tasks by design (design §10 testability table). Non-algorithmic view-layer assertions are consolidated in task 7.7.
- Smoke test 7.7's "Card reachable from two Decks after one is deleted" overlaps with B11 from task 4.3. This is intentional: `CoreDataDeckStoreTests` validates it against Core Data; the smoke test validates it at the view-model/store boundary using `InMemoryDeckStore` so view-model tests can rely on the same invariant.
- `HanaHouUITests/` is not exercised in P0 (design §10). The existing `HanaHouUITests/HanaHouUITestsLaunchTests.swift` should continue to compile after the `ContentView` → `DeckManagementRootView` swap; if it fails to build, fix minimally — do not add new UI tests.
- If task 8.2's Info.plist approach proves insufficient at runtime (iPadOS scene-level overrides), add a `UIApplicationDelegateAdaptor` fallback per design §8 and record the fallback as a new decision in `docs/decisions.md`. Do not introduce per-view overrides.
- Task 9.4 may reduce to a no-op if the existing D026/D027/D028 entries are already sufficient; re-check before writing new decisions.
