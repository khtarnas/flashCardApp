# Design Document — Deck Management (P0)

## Overview

This design describes how HanaHou implements the P0 deck management feature specified in `.kiro/specs/deck-management/requirements.md`. It covers the list of decks, creating/editing/deleting user-created decks, the system-managed "All Cards" entry, deck-name validation, the Core Data schema, navigation, and the portrait orientation lock.

Scope boundaries (per the requirements introduction):
- In scope: listing, creating, editing, deleting user-created decks; the "All Cards" system entry; the Core Data schema needed to support both.
- Out of scope: card-level CRUD, study mode, Apple Pencil, networking. The Card entity is designed here only because the Deck ↔ Card relationship must be many-to-many from day one (D003).

Referenced decisions: D003 (many-to-many Card-Deck), D007 (per-feature TDD), D009 (swappable ordering strategy pattern), D012 (detach-on-delete + "All Cards"), D013 (stack navigation), D014 (portrait only). Referenced docs: `docs/data-model.md`, `docs/p0.md`, `.kiro/steering/tech.md`.

## Architecture

The feature is split into four layers with strict, one-way dependencies. Each layer is replaceable without rewriting its neighbors — the "everything is mutable" principle from `.kiro/steering/product.md`.

```
┌──────────────────────────────────────────────────────────────┐
│  Views (SwiftUI)                                             │
│  DeckListView, DeckEditorView, DeleteConfirmation,           │
│  AllCardsView (placeholder), DeckManagementRootView          │
└──────────────────────────────┬───────────────────────────────┘
                               │ observes @Published state,
                               │ sends intents
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  View Models (ObservableObject, @MainActor)                  │
│  DeckListViewModel, DeckEditorViewModel                      │
│  - owns UI state, routes intents, surfaces errors            │
└──────────────────────────────┬───────────────────────────────┘
                               │ calls
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  Domain Services (pure Swift, no SwiftUI, no Core Data)      │
│  DeckNameValidator, DeckOrderingStrategy,                    │
│  DeckListComposer (merges user decks + All Cards entry)      │
└──────────────────────────────┬───────────────────────────────┘
                               │ uses
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  Persistence (DeckStore protocol)                            │
│  CoreDataDeckStore (prod), InMemoryDeckStore (tests)         │
│  - CRUD on Deck records, change publisher                    │
└──────────────────────────────────────────────────────────────┘
```

Key conventions:
- **Domain services know nothing about Core Data or SwiftUI.** They operate on plain Swift value types (`DeckSnapshot`, `DeckDraft`, `DeckListItem`).
- **View models depend on protocols, not concrete types.** This is how we get testability without the simulator (see §11).
- **The view model is the only layer allowed to talk directly to the store.** Views never touch Core Data.
- **Change propagation is pull-based via a `DeckStoreChange` publisher on the store protocol.** The list view model subscribes and re-queries on change. This keeps Core Data's `NSManagedObjectContext` out of the view layer.

## Data Model

### Core Data schema

The existing template `Item` entity is removed. The `HanaHou.xcdatamodeld` bundle gets two entities.

#### `Deck` entity

| Attribute | Type | Optional | Default | Notes |
|-----------|------|----------|---------|-------|
| `id` | UUID | NO | — | Primary key. Set in code on insert. |
| `name` | String | NO | — | Stored as-entered (not trimmed). Trimming is applied at comparison time so round-trip display preserves user intent. |
| `frontLanguageRaw` | String | NO | — | `Language.rawValue`. |
| `backLanguageRaw` | String | NO | — | `Language.rawValue`. |
| `createdAt` | Date | NO | — | Set by the store on insert. |
| `updatedAt` | Date | NO | — | Set equal to `createdAt` on insert; bumped on successful edit (Req 6.5). |

**Relationships:**
- `cards` → `Card` (to-many, nullify on delete of Deck). Inverse: `Card.decks`.

**Constraints:**
- `id` marked as the constraint (`uniquenessConstraints = [["id"]]`) to guarantee primary-key uniqueness.
- Name uniqueness is **not** enforced via Core Data's `uniquenessConstraints`. Rationale: requirements 5.2 and the Glossary define "unique name" as trimmed, case-sensitive, and the reserved-name rule is trimmed, case-insensitive. Core Data constraints compare stored values byte-for-byte and cannot express "trimmed." Enforcing at the constraint level would either (a) require us to store a trimmed canonical form and lose the user's spacing, or (b) allow duplicates like `"Japanese "` vs `"Japanese"`. We enforce name rules in `DeckNameValidator` (the single source of truth) and re-check in `CoreDataDeckStore.create/update` as a final defense before save.

Indexing: none in P0. Deck volumes are small (dozens at most for a personal app). If the list ever grows large, a Core Data fetch index on `createdAt` would be the first addition.

#### `Card` entity

Included in P0 so the many-to-many relationship (D003) can be modeled from day one. Card CRUD is out of scope; the entity exists to hold the relationship.

| Attribute | Type | Optional | Default | Notes |
|-----------|------|----------|---------|-------|
| `id` | UUID | NO | — | Primary key. |
| `frontText` | String | NO | `""` | Populated by a later spec. |
| `backText` | String | NO | `""` | Populated by a later spec. |
| `createdAt` | Date | NO | — | Set on insert. |

**Relationships:**
- `decks` → `Deck` (to-many, nullify on delete of Card). Inverse: `Deck.cards`.

This creates a native Core Data many-to-many with nullify semantics on both sides, which is exactly what D012 requires: deleting a Deck detaches its cards without deleting them, and the cards are still reachable via the "All Cards" view.

### Language enum

Lives in `HanaHou/Models/Language.swift`.

```swift
enum Language: String, CaseIterable, Codable, Hashable {
    case english, japanese, spanish, mandarin,
         hawaiian, other
}
```

Stored as the raw `String` in Core Data. The view model does the `Language(rawValue:)` conversion, defaulting to `.other` if an unknown value is ever read back (forward compatibility — a future release could add more cases without requiring a migration).

### Value types (domain layer)

These are plain Swift structs that cross the store boundary. Keeping Core Data objects (`NSManagedObject`) out of the domain layer is what makes the `InMemoryDeckStore` test double possible.

```swift
struct DeckSnapshot: Equatable, Identifiable {
    let id: UUID
    let name: String
    let frontLanguage: Language
    let backLanguage: Language
    let createdAt: Date
    let updatedAt: Date
}

struct DeckDraft: Equatable {
    var name: String
    var frontLanguage: Language
    var backLanguage: Language
}
```

### Migration from the template `Item` entity

The template `Item` entity has never held real data — the app has not shipped. Migration strategy:

1. Delete `Item` from `HanaHou.xcdatamodel`.
2. Add `Deck` and `Card` entities as described above.
3. Bump `HanaHou.xcdatamodel`'s version (create `HanaHou 2.xcdatamodel` inside the `.xcdatamodeld` bundle) and set it as the current version. This gives us a versioned starting point for future migrations.
4. Enable lightweight migration on `NSPersistentContainer` via the store description's `shouldMigrateStoreAutomatically = true` and `shouldInferMappingModelAutomatically = true`. Because the old `Item` entity has no related data, the migration is effectively a destructive schema replacement on any dev machine that ran the template.
5. Delete `ContentView`'s `Item`-specific code; replace with `DeckManagementRootView` (see §7).

Rationale for "bump version even though nothing ships": establishes a baseline so the very next schema change (adding `StudyEvent` in P2) has a from-version to migrate from. Cheap now, painful later.

### Name-uniqueness and reserved-name enforcement

Three distinct checks, each with a distinct error type (Req 5.5):

1. **Empty:** `trimmed(name).isEmpty` → `DeckNameError.empty`.
2. **Reserved:** `trimmed(name).lowercased() == "all cards"` (case-insensitive compare with `.caseInsensitive` options against each literal reserved name) → `DeckNameError.reserved`.
3. **Duplicate:** among existing user decks, any deck (other than the one being edited) whose trimmed name equals `trimmed(name)` under a case-sensitive compare → `DeckNameError.duplicate`.

`trimmed(_:)` uses `trimmingCharacters(in: .whitespacesAndNewlines)` — which covers spaces, tabs, and newlines — matching the Glossary's "leading and trailing whitespace."

The validator is a pure function of `(proposedName, existingDecks, editingDeckId?) → Result<String, DeckNameError>`. It's called from both the view model (for live feedback) and the store (for defense-in-depth immediately before save).

## All Cards Representation

The requirements explicitly leave this open. Three options, with trade-offs:

| Option | Pros | Cons |
|--------|------|------|
| **A. Synthetic list item in the view model** | Never stored; no reserved-name row in the DB; no risk of accidental edit/delete via Core Data faults; clean separation | Selection routing needs to distinguish two cases (`.allCards` vs `.deck(id)`) |
| **B. Sentinel `Deck` row with a known id** | Uniform list type; existing deck-selection code works unchanged | A reserved row sitting in the store is easy to edit/delete by mistake; every mutating code path needs a "not the sentinel" guard; complicates the uniqueness story because the sentinel's `name` occupies a reserved value in the DB |
| **C. Dedicated navigation case, no list entry** | Simplest data model | Requirement 1.3 and 8.1 explicitly say it must appear in the list |

**Decision: Option A — synthetic list item.** It matches Req 8.5 ("system concept rather than a user-created Deck record") directly and keeps the Core Data model clean. The reserved-name check (Req 5.3) prevents any user-created deck from colliding with it.

Concretely, the list view model exposes:

```swift
enum DeckListItem: Identifiable, Equatable {
    case allCards                         // id: .allCards
    case deck(DeckSnapshot)               // id: .deck(UUID)

    enum ID: Hashable { case allCards, deck(UUID) }
    var id: ID { ... }
}
```

`DeckListComposer.compose(userDecks:strategy:)` produces `[.allCards] + strategy.order(userDecks).map(.deck)`, placing All Cards at a fixed position (Req 1.4) independent of the ordering strategy.

On selection, navigation uses the same enum to route. The "rename" and "delete" commands on `.allCards` short-circuit with a message (Req 8.3, 8.4) at the view model — they never reach the store.

## Deck Ordering Strategy

Mirrors the swappable-strategy pattern D009 establishes for card ordering.

```swift
protocol DeckOrderingStrategy {
    func order(_ decks: [DeckSnapshot]) -> [DeckSnapshot]
}

struct CreationDateAscendingOrdering: DeckOrderingStrategy {
    func order(_ decks: [DeckSnapshot]) -> [DeckSnapshot] {
        decks.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    }
}
```

The `id.uuidString` tiebreaker guarantees deterministic ordering when two decks share a `createdAt` (possible in tests with a fake clock). `CreationDateAscendingOrdering` is the P0 default (Req 1.6).

Injection: the app entry point (`HanaHouApp`) constructs one strategy and hands it to `DeckListViewModel`'s initializer. The strategy is stored as the protocol type — any future replacement (e.g., `MostRecentlyUpdatedOrdering` consuming the `updatedAt` we persist per Req 6.7) is a one-line change at the composition root. `DeckListView` sees only the ordered list and has no knowledge of ordering.

## Validation Rules

Where each rule lives:

| Rule | Where checked | Why |
|------|---------------|-----|
| Front/back language is from `Language` enum (Req 2.2) | Compile time (type system) | Enum selection in SwiftUI `Picker`; impossible to submit a non-enum value |
| Empty name (Req 2.4, 3.3, 5.1) | `DeckNameValidator` (live + on submit) | Same rule for create and edit (Req 5.4) |
| Reserved name (Req 2.6, 3.5, 5.3) | `DeckNameValidator` | Same rule for create and edit (Req 5.4) |
| Duplicate name (Req 2.5, 3.4, 5.2) | `DeckNameValidator` with the full current deck set | Must exclude the deck being edited from the duplicate comparison |
| Name unchanged on edit (trivial case) | `DeckEditorViewModel` | Submitting the editor without changes should succeed (no spurious duplicate error against itself) — handled by the `editingDeckId` parameter to the validator |

Error type:

```swift
enum DeckNameError: Error, Equatable {
    case empty
    case reserved(name: String)
    case duplicate(name: String)
}
```

Distinct cases give the view model distinct, localizable messages (Req 5.5):

- `.empty` → "Name is required."
- `.reserved(name)` → "\"\(name.trimmed)\" is reserved and cannot be used."
- `.duplicate(name)` → "A deck named \"\(name.trimmed)\" already exists."

The `DeckEditorViewModel` exposes `@Published var nameError: DeckNameError?` which the view binds to an inline message under the name field. Submission is gated on `nameError == nil`.

Defense-in-depth: `CoreDataDeckStore.create` and `.update` re-run the validator against a fresh fetch inside the same `perform` block before save. If the validator disagrees with the view model (a concurrent edit, say), the store returns the appropriate `DeckNameError` instead of writing.

## Views and Navigation

### Topology

`NavigationStack` (per D013) rooted at `DeckManagementRootView`.

```
DeckManagementRootView  (NavigationStack root)
 └─ DeckListView                                    // Req 1, Req 8
     ├─ toolbar "+" → pushes DeckEditorView(.create)
     ├─ row tap on .deck(id) → pushes (future) DeckDetailView; P0 shows edit sheet
     ├─ row tap on .allCards → pushes AllCardsPlaceholderView
     └─ swipe-to-delete on .deck(id) → presents DeleteConfirmationDialog
```

`DeckEditorView` is **pushed**, not presented modally. Rationale: D013 calls for stack navigation; modal sheets introduce a second navigation axis and complicate the stack. The editor can still be dismissed with a standard back button, and Cancel on the editor pops the stack.

### Views

- **`DeckManagementRootView`**: owns the `NavigationStack` path and holds the `DeckListViewModel` as a `@StateObject`.
- **`DeckListView`**: `List` of `DeckListItem`. The `.allCards` row is rendered with a distinct icon (`square.stack.3d.up`) and label "All Cards" and is non-swipable (no delete action, no edit action). User-deck rows show name, front/back language pair (e.g., "English → Japanese"), and provide swipe-to-delete. Empty state (no user decks) shows a friendly "No decks yet. Tap + to create one." message. The "All Cards" entry is always present regardless of empty state (Req 8.1).
- **`DeckEditorView`**: two modes via `DeckEditorViewModel.Mode { case create, edit(DeckSnapshot) }`. Fields: name (`TextField`), front language (`Picker`), back language (`Picker`). Save button disabled while `nameError != nil` or name is empty. Save triggers the view model's submit; on success the stack pops.
- **`DeleteConfirmationDialog`**: `.confirmationDialog` modifier. Copy: "Delete \"\(deckName)\"? Cards in this deck will be kept and remain visible in All Cards." (reflects D012).
- **`AllCardsPlaceholderView`**: P0 placeholder that displays "All Cards view — coming in the card-management spec." Navigation wiring exists so later specs can swap the view without touching the list.

### Live refresh (Req 1.8)

`DeckStore` exposes a change publisher:

```swift
protocol DeckStore {
    func fetchAll() throws -> [DeckSnapshot]
    func create(_ draft: DeckDraft) throws -> DeckSnapshot
    func update(id: UUID, with draft: DeckDraft) throws -> DeckSnapshot
    func delete(id: UUID) throws
    var changes: AnyPublisher<Void, Never> { get }
}
```

`CoreDataDeckStore` emits on `changes` in response to `NSManagedObjectContextDidSave`. The list view model subscribes in `init`, calls `fetchAll()` on each signal, re-runs the ordering strategy, and updates `@Published var items`. SwiftUI re-renders automatically. The `InMemoryDeckStore` emits on the same publisher after any mutation, so view-model tests can drive live-refresh behavior deterministically.

## Orientation Lock

Single point of change (Req 7.5). Options considered:

| Option | Single-point? | Removable later? | Choice |
|--------|--------------|------------------|--------|
| Info.plist `UISupportedInterfaceOrientations` | Yes (one key) | Yes (edit plist) | **Selected** |
| `UIApplicationDelegate.supportedInterfaceOrientationsFor:` adaptor | Yes (one method) | Yes | Fallback if plist alone doesn't hold |
| Per-view `.supportedInterfaceOrientations` on every scene | No — scattered | Painful | Rejected |

**Decision: Info.plist.** Set `UISupportedInterfaceOrientations~ipad` to `["UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown"]` (both portrait variants so the iPad doesn't flip to landscape when the user rotates). When landscape support is added in a future priority, editing this one plist key unlocks all four orientations.

If Info.plist alone is insufficient in practice (iPadOS occasionally honors scene-level overrides), we add a `SceneDelegate`-less adaptor via an `UIApplicationDelegateAdaptor` on `HanaHouApp` that implements `application(_:supportedInterfaceOrientationsFor:)` returning `.portrait`. That adaptor is the second — and still single — possible point of change. We do not add per-view overrides.

The orientation lock is global (not scoped to deck management screens). Req 7.4 says "suppress rotation … while any deck management screen is active" and Req 7.3 says "lock the interface orientation to Portrait" — the simpler global lock satisfies both in P0.

## Offline / No Network

Confirmed: zero network dependencies introduced. All operations — reads, writes, deletes, change notifications — occur against the local Core Data store. No `URLSession`, no CloudKit, no background fetch. This satisfies D002 and the tech.md "offline-first" constraint.

## Error Handling

Error sources and how they surface:

| Source | Error type | Surfacing |
|--------|-----------|-----------|
| Validation (create or edit) | `DeckNameError` | Inline message under the name field in `DeckEditorView`. Save button disabled. No alert. |
| Core Data save failure (disk full, corrupted store, unknown) | `DeckStoreError.persistenceFailed(underlying:)` | Alert on the editor ("Couldn't save: \(localizedDescription). Please try again.") with a single OK button. The edit is not dismissed so the user doesn't lose their input. |
| Delete failure (same root causes) | `DeckStoreError.persistenceFailed(underlying:)` | Alert on the list view. The deck remains in the list since the delete rolled back. |
| Attempt to delete/rename `.allCards` | `AllCardsActionError.notAllowed` | Short inline message (Req 8.3, 8.4). These paths should normally be unreachable because the UI hides the affordances — the error is defense-in-depth for programmatic callers. |

`DeckStoreError` values are logged via `os.Logger` (`subsystem: "com.hanahou", category: "DeckStore"`) at the error level. No crash-on-save: the template's `fatalError` calls in `Persistence.swift` are replaced with a `throws` API that propagates to the view model.

No partial success is possible — each operation is a single `context.save()`. If save throws, the `NSManagedObjectContext` is rolled back via `context.rollback()` so the in-memory state matches what's on disk.

## Testability

The project follows TDD per D007; design must be detailed enough to write tests from.

### DeckStore protocol with an in-memory test double

```swift
final class InMemoryDeckStore: DeckStore {
    private var decks: [UUID: DeckSnapshot] = [:]
    private let changesSubject = PassthroughSubject<Void, Never>()
    var changes: AnyPublisher<Void, Never> { changesSubject.eraseToAnyPublisher() }
    var clock: () -> Date = Date.init  // injectable for deterministic createdAt/updatedAt

    // create/update/delete call changesSubject.send() after mutating
    // create enforces the same validation rules as CoreDataDeckStore
}
```

The in-memory store runs entirely synchronously and has no Core Data dependency, which means:
- `DeckNameValidator` tests are pure-function tests (no store needed).
- `DeckOrderingStrategy` tests feed hand-built `[DeckSnapshot]` arrays and assert on the output order.
- View-model tests construct an `InMemoryDeckStore`, inject it into the view model, drive the view model's intents, and assert on `@Published` state — no simulator, no Core Data.

### Layer-by-layer testability

| Layer | Tested against | Test file home |
|-------|---------------|----------------|
| `DeckNameValidator` | Pure Swift values | `HanaHouTests/Domain/DeckNameValidatorTests.swift` |
| `DeckOrderingStrategy` (each concrete type) | Pure Swift values | `HanaHouTests/Domain/DeckOrderingStrategyTests.swift` |
| `DeckListComposer` | Pure Swift values | `HanaHouTests/Domain/DeckListComposerTests.swift` |
| `DeckListViewModel` | `InMemoryDeckStore` + fake strategy | `HanaHouTests/ViewModels/DeckListViewModelTests.swift` |
| `DeckEditorViewModel` | `InMemoryDeckStore` | `HanaHouTests/ViewModels/DeckEditorViewModelTests.swift` |
| `CoreDataDeckStore` | In-memory Core Data stack (`NSInMemoryStoreType` or `/dev/null` URL) | `HanaHouTests/Persistence/CoreDataDeckStoreTests.swift` |
| Views | Not unit-tested in P0 | (UI tests live in `HanaHouUITests/`, deferred) |

The `CoreDataDeckStore` tests use the existing `PersistenceController(inMemory: true)` pattern from `HanaHou/Persistence.swift`, extended to vend a `CoreDataDeckStore` configured with the in-memory context.

### TDD note

The tests phase comes next (per D007). This design intentionally names every type, lists every method signature, and pins every validation rule so test cases can be written directly from this document without further interpretation.

## Testing Approach

Per D021, P0 uses **example-based tests** (hand-picked inputs with expected outputs) rather than property-based testing. The validation rules are simple — three rules over a small input space — and the app is personal-scale, so example-based tests are more readable and easier to debug. PBT will be revisited when algorithm complexity warrants it (e.g., SRS scheduling in P2).

Framework: **XCTest** only (tech.md: Apple frameworks only, no third-party dependencies in P0).

### Behaviors to cover

Each behavior is exercised with a small, explicit set of example cases. Requirement traceability is listed for each.

**B1 — Whitespace-only names rejected as `.empty`.** Validator returns `.failure(.empty)` and the store refuses to mutate. Examples: `""`, `"   "`, `"\t"`, `"\n"`, `" \t\n "`. *(Req 2.4, 3.3, 5.1, 5.4)*

**B2 — Reserved-name variants rejected as `.reserved`.** Validator returns `.failure(.reserved)` and the store refuses to mutate. Examples: `"All Cards"`, `"all cards"`, `"ALL CARDS"`, `"  All Cards  "`, `"aLL cArDs"`. *(Req 2.6, 3.5, 5.3, 5.4, 5.6, 6.3, 8.5)*

**B3 — Duplicate-name variants rejected as `.duplicate`, with edit-mode excluding the target deck.** Given a stored deck named `"Japanese"`:
- Create with `"Japanese"` → `.duplicate`.
- Create with `"  Japanese  "` → `.duplicate` (trimmed match).
- Create with `"japanese"` → valid (case-sensitive, not a duplicate).
- Edit the existing deck, resubmit `"Japanese"` unchanged → valid (self-collision excluded).
- Edit the existing deck to `"Korean"` when another deck `"Korean"` exists → `.duplicate`. *(Req 2.5, 3.4, 5.2, 5.4, 6.2)*

**B4 — Validation-error messages are distinct.** The three rendered strings for `.empty`, `.reserved("All Cards")`, and `.duplicate("Japanese")` are all different. *(Req 5.5)*

**B5 — Create round-trip.** With an injected clock returning a fixed time `t`, creating a valid draft returns a `DeckSnapshot` whose fields equal the draft, with `createdAt == t` and `updatedAt == t`. `fetchAll()` afterwards contains the new snapshot. *(Req 2.3, 2.7, 2.8, 6.4)*

**B6 — Edit round-trip.** With the clock advanced to `t' > D.updatedAt`, updating an existing deck *D* with a valid draft returns a snapshot whose fields equal the draft, whose `createdAt` is unchanged, and whose `updatedAt == t'`. `fetchAll()` afterwards reflects the change. *(Req 3.2, 3.6, 6.5, 6.7)*

**B7 — `CreationDateAscendingOrdering` sorts by `createdAt` ascending with `id.uuidString` tiebreaker.** Example inputs: three decks with distinct `createdAt`; and two decks sharing a `createdAt` (checks tiebreaker determinism). *(Req 1.6)*

**B8 — The list contains exactly one `.allCards` entry at index 0, strategy-independent.** Seed 0 decks, 1 deck, and 3 decks. Run with the P0 strategy and a stub reverse-ordering strategy. In every case, `items[0] == .allCards` and `items.filter { $0 == .allCards }.count == 1`. *(Req 1.3, 1.4, 8.1)*

**B9 — The user-deck subsequence of the list equals `strategy.order(storedDecks)`.** Seed three decks, run with both the P0 strategy and a stub strategy, and assert that dropping the `.allCards` head yields the strategy's output. *(Req 1.1, 1.5)*

**B10 — Store mutations propagate to the list view model.** Starting from a seeded store, perform `create`, then `update`, then `delete`; after each, the view model's `items` reflects the new store contents. *(Req 1.8)*

**B11 — Delete removes the target deck and detaches (does not delete) its cards.** Seed deck *D* with cards *C1* (only in *D*) and *C2* (in *D* and another deck *E*). After `delete(id: D.id)`: *D* is gone; *E* is unchanged; *C1* and *C2* still exist; *C1.decks* is empty; *C2.decks* contains only *E*. *(Req 4.2, 4.3)*

**Example-based tests for UI affordances, navigation wiring, and configuration** (non-algorithmic):
- Info.plist declares only portrait orientations. *(Req 7.2, 7.3, 7.4, 7.5)*
- `DeckEditorViewModel` exposes bindable name / front / back fields. *(Req 2.1, 3.1)*
- Editor in edit mode is pre-populated with the target deck's values. *(Req 3.1)*
- Root view uses `NavigationStack`. *(Req 7.1)*
- Selecting `.allCards` routes to `AllCardsPlaceholderView`. *(Req 8.2)*
- Attempting rename/delete on `.allCards` returns `AllCardsActionError.notAllowed`. *(Req 4.4, 8.3, 8.4)*
- A `Card` associated with two `Deck`s is reachable from both. *(Req 6.6)*
- `DeckListItem.deck(_)` exposes name, front language, back language. *(Req 1.2)*

### Test layering

| Layer | Tested against | Behaviors |
|-------|----------------|-----------|
| `DeckNameValidator` | Plain Swift values | B1, B2, B3 |
| `DeckOrderingStrategy` | Plain Swift values | B7 |
| `DeckListComposer` | Plain Swift values | B8, B9 |
| `DeckListViewModel` | `InMemoryDeckStore` + injectable strategy | B8, B9, B10 |
| `DeckEditorViewModel` | `InMemoryDeckStore` + injectable clock | B1, B2, B3, B4, B5, B6 |
| `CoreDataDeckStore` | In-memory Core Data stack | B1, B2, B3, B5, B6, B11 (validator parity + delete semantics) |

The validator and ordering strategy are tested once as pure functions; the store rerun of the validator is tested via `CoreDataDeckStore` to confirm parity.

## Open Design Decisions

Decisions left for implementation time, listed so they can be resolved before tasks:

1. **Editor presentation: pushed vs sheet.** This design chose pushed to align with D013. If iPad feel suggests a sheet is better during implementation, revisit with user approval and add a decision entry.
2. **Orientation-lock fallback.** Info.plist is the selected single point. If iPadOS behavior requires a `UIApplicationDelegateAdaptor` fallback, that adaptor becomes the single point instead. Record in `docs/decisions.md` if the fallback is needed.
3. **`updatedAt` as a future ordering input.** The P0 strategy uses `createdAt` with a `UUID` tiebreaker. A future strategy keyed on `updatedAt` is trivial because the value is already persisted (Req 6.7). No action required before tasks.
4. **Language enum ordering in pickers.** Alphabetical vs a curated order. Cosmetic; resolve during implementation.
5. **Copy for error and confirmation messages.** Placeholder strings in this design; finalize during implementation.

Items to add to `docs/decisions.md` after this design is approved:
- Decision: "All Cards represented as synthetic view-model item, not a stored Deck row" (rationale in §4).
- Decision: "Name uniqueness enforced in code (validator + store), not via Core Data `uniquenessConstraints`" (rationale in §3).
- Decision: "Orientation lock lives in Info.plist as the single point of change" (rationale in §8).
