# AGENTS.md — HanaHouTests/ViewModels/

Tests for the `@MainActor` view models under `HanaHou/ViewModels/`.

## Current contents

| File | Covers |
|------|--------|
| `DeckEditorViewModelTests.swift` | Initialization in both modes, B1/B2/B3 validation gating, B4 distinct error messages, B5 create success, B6 edit success with `updatedAt` advancing. |
| `DeckListViewModelTests.swift` | B8 (`.allCards` invariants), B9 (user-deck subsequence matches strategy), B10 (store mutations propagate), All Cards rename/delete defense-in-depth. |

## Directives

- Mark the test class `@MainActor` — the view models are main-actor isolated.
- Back the view model with `InMemoryDeckStore`; use `waitBriefly()` (50ms expectation) to let Combine emissions hop to the main queue before asserting.
