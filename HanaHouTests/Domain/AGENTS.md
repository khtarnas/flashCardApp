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
| `SelfGradeTests.swift` | Shape and label invariants for the study-mode `SelfGrade` enum (Req 10 AC 2, Req 10 AC 3.12, Req 9 AC 6, D036): exactly three cases, each label non-empty and distinct, confidence-oriented D036 labels wired to `.know`/`.close`/`.noIdea`, `Equatable` + `CaseIterable` conformance, stable `String` raw value for future P1 persistence per D039. |

## Directives

- Pure-function tests — no store, no simulator concerns.
- Use deterministic inputs (explicit `UUID(uuidString:)`, `Date(timeIntervalSince1970:)`).
