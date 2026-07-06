# AGENTS.md — HanaHou/Views/

SwiftUI view layer for deck and card management.

## Current contents

| File | Purpose |
|------|---------|
| `DeckManagementRootView.swift` | Composition point. Owns `DeckListViewModel` via `@StateObject`, hosts the `NavigationStack`, and routes through `DeckManagementRoute` (which now includes `.study(DeckSnapshot)`) to the deck editor, card list, card editor, All Cards, and the new Study destinations. |
| `DeckListView.swift` | Home-screen list. Renders user decks ordered by the injected strategy, with the synthetic `.allCards` row pinned at the top. Toolbar `+` creates a new deck; swipe-to-delete surfaces a `.confirmationDialog`. Tapping a user-deck row pushes `.cardList(deck)` (D031). |
| `DeckEditorView.swift` | Create/edit form for decks. Name `TextField`, front/back `Picker<Language>`, inline `DeckNameError` message under the name field. Save is gated on `nameError == nil`. |
| `CardListView.swift` | Per-Deck card list. Renders `CardRowItem` rows, toolbar `+` for new card, toolbar "Study" button (enabled when the deck has cards — pushes `.study(deck)` per the study-mode spec), toolbar "Edit Deck" to push `.editDeck(deck)` (the new home for rename/delete after D031), swipe-to-delete with a confirmation dialog. No study affordance on `AllCardsView` in P0 per D041 — deferred, not excluded. |
| `AllCardsView.swift` | Lists every card in the store regardless of deck membership. Orphan rows carry a "Not in any deck" badge. Tapping a row pushes `.editCard(snapshot)`. No "+" affordance — creating orphans is out of scope for P0. |
| `CardEditorView.swift` | Create/edit form for cards. `Form` with front and back `TextField`s, inline `CardTextError` messages under each field, Save disabled when either field is empty or either error is present. Edit-mode shows a "Danger Zone" section with a destructive delete button. |
| `StudyView.swift` | The P0 study surface. Single SwiftUI view that switches body content on `StudySessionViewModel.session.phase`: `.frontRevealed` (progress label + front text + "Show Back" button), `.backRevealed` (progress label + front+back text + three grade buttons sourced from `SelfGrade.allCases` with `SelfGrade.label`), `.completed` (inline `StudyCompletionView`), and `.emptyDeck` (empty-state message + "Back to deck"). Toolbar Exit button visible in the two active phases. Inherits the Info.plist portrait lock (D014/D028) — no study-side override. |
| `StudyCompletionView.swift` | Presented when the session reaches `.completed` (Req 6 AC 1 per D010). Stateless; takes `deckName` and an `onReturnHome` callback. No statistics or grade counts in P0 — a summary screen is a future feature. |

## Directives

- Views never touch Core Data directly — they drive view models via bindings and intents.
- Per D013, navigation is `NavigationStack` only. No modal sheets in P0.
- Empty state is an overlay; the All Cards row stays visible in the deck list (Req 8.1).
- Views have no unit tests in P0 — non-algorithmic assertions live in `HanaHouTests/Views/DeckManagementSmokeTests.swift`.
