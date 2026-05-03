# AGENTS.md — HanaHouTests/Domain/

Tests for the pure domain services under `HanaHou/Domain/`.

## Current contents

| File | Covers |
|------|--------|
| `DeckNameValidatorTests.swift` | B1 (empty), B2 (reserved), B3 (duplicate with edit-mode self-exclusion). |
| `DeckOrderingStrategyTests.swift` | B7 (`CreationDateAscendingOrdering`: ascending by `createdAt` with `id.uuidString` tiebreaker). |
| `DeckListComposerTests.swift` | B8 (exactly one `.allCards` at index 0, strategy-independent), B9 (user-deck subsequence == `strategy.order(stored)`). |
| `CardTextValidatorTests.swift` | C1 (empty front → `.missingFront`), C2 (empty back → `.missingBack`, plus front-priority when both are empty). Exercises whitespace/newline trimming. |
| `CardOrderingStrategyTests.swift` | C8 (`CardCreationDateAscendingOrdering`: ascending by `createdAt` with `id.uuidString` tiebreaker; empty/single-element/mixed fixtures). |

## Directives

- Pure-function tests — no store, no simulator concerns.
- Use deterministic inputs (explicit `UUID(uuidString:)`, `Date(timeIntervalSince1970:)`).
