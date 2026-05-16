# AGENTS.md — HanaHouTests/Views/

Smoke tests for the SwiftUI view layer. P0 does not unit-test view bodies; this file captures the non-algorithmic assertions at the view-model boundary.

## Current contents

| File | Covers |
|------|--------|
| `DeckManagementSmokeTests.swift` | Deck-side: navigation root compiles (Req 7.1), bindable editor fields (Req 2.1, 3.1), edit-mode pre-population (Req 3.1), All Cards rename/delete rejection (Req 4.4, 8.3, 8.4), `DeckListItem.deck` exposes name/languages (Req 1.2), B11 re-asserted at the store boundary (Req 6.6, 4.3). Card-side additions: `CardEditorViewModel` bindable `frontText`/`backText`, card-editor edit-mode pre-population, `CardRowItem` exposes `frontText`/`backText`/`isOrphan` (Req 2.2, 5.3), and the `DeckManagementRoute` cases (`.cardList`, `.createCard`, `.editCard`) exist and round-trip their payloads (route-change assertion for Req 5.7, 8.1). Study-mode additions: `.study(deck)` route resolves to `StudyView`; `CardListView` identifier contract for the Study toolbar button; `StudyCompletionView` deck-name rendering and `onReturnHome` callback semantics; view-model-level smoke proof that grading every card transitions the session to `.completed` so the completion surface takes over. |

## Directives

- Do not reach into SwiftUI mangled generics — assert on observable state and behavior.
- Intentional overlap with other test files is fine where the Notes section of a spec's tasks file calls it out.
