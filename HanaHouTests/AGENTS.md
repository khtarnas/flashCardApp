# AGENTS.md — HanaHouTests/

Unit tests for HanaHou using XCTest (D021 — no swift-testing for P0).

## Current contents

| Path | Purpose |
|------|---------|
| `HanaHouTests.swift` | Template placeholder test file. |
| `Domain/` | Tests for `DeckNameValidator`, `DeckOrderingStrategy`, `DeckListComposer`. |
| `Persistence/` | Tests for `InMemoryDeckStore` and `CoreDataDeckStore` (with an in-memory Core Data stack). |
| `ViewModels/` | Tests for `DeckEditorViewModel` and `DeckListViewModel` against `InMemoryDeckStore`. |
| `Views/` | Non-algorithmic smoke tests covering navigation root, bindable editor fields, All Cards defense-in-depth, and the Card-reachable-from-two-decks invariant. |
| `Configuration/` | Build-setting / Info.plist assertions (e.g., portrait orientation lock). |

## Directives

- TDD per D007: write tests first, then implementation.
- Example-based tests only (D021).
- XCTest only — no swift-testing, no third-party testing libraries (tech.md).
- Use `InMemoryDeckStore` for view-model tests; use in-memory Core Data for `CoreDataDeckStore` tests.
- Each test file's header lists the behaviors (B1–B11) and requirement IDs it validates.
