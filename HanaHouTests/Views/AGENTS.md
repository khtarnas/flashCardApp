# AGENTS.md — HanaHouTests/Views/

Smoke tests for the SwiftUI view layer. P0 does not unit-test view bodies; this file captures the non-algorithmic assertions (navigation root instantiates, editor fields are bindable, etc.) at the view-model boundary.

## Current contents

| File | Covers |
|------|--------|
| `DeckManagementSmokeTests.swift` | Navigation root compiles (Req 7.1), bindable editor fields (Req 2.1, 3.1), edit-mode pre-population (Req 3.1), All Cards rename/delete rejection (Req 4.4, 8.3, 8.4), `DeckListItem.deck` exposes name/languages (Req 1.2), and B11 re-asserted at the store boundary (Req 6.6, 4.3). |

## Directives

- Do not reach into SwiftUI mangled generics — assert on observable state and behavior.
- Intentional overlap with other test files is fine where the Notes section of `.kiro/specs/deck-management/tasks.md` calls it out.
