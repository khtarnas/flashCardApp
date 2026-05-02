# AGENTS.md — HanaHou/Views/

SwiftUI view layer for deck management.

## Current contents

| File | Purpose |
|------|---------|
| `DeckManagementRootView.swift` | Composition point. Owns `DeckListViewModel` via `@StateObject`, hosts the `NavigationStack`, and routes to editor / placeholder destinations via `DeckManagementRoute`. |
| `DeckListView.swift` | Home-screen list. Renders user decks ordered by the injected strategy, with the synthetic `.allCards` row pinned at the top. Toolbar `+` creates a new deck; swipe-to-delete surfaces a `.confirmationDialog`. |
| `DeckEditorView.swift` | Create/edit form. Name `TextField`, front/back `Picker<Language>`, inline `DeckNameError` message under the name field. Save is gated on `nameError == nil`. |
| `AllCardsPlaceholderView.swift` | Placeholder destination for the `.allCards` row. Will be replaced by the card-management spec. |

## Directives

- Views never touch Core Data directly — they drive view models via bindings and intents.
- Per D013, navigation is `NavigationStack` only. No modal sheets in P0.
- Empty state is an overlay; the All Cards row stays visible (Req 8.1).
- Views have no unit tests in P0 — non-algorithmic assertions live in `HanaHouTests/Views/DeckManagementSmokeTests.swift`.
