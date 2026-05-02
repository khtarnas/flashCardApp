# AGENTS.md — HanaHou (Root)

## Project

HanaHou is a personal iPadOS flashcard app for language learning. Built with Swift, SwiftUI, and Core Data.

## Before making changes

1. Read `.kiro/steering/steering.md` for project rules and dev process.
2. Read the relevant priority tier doc (`docs/p0.md`, etc.) for current scope.
3. Check `docs/open-questions.md` — do not implement features with unresolved questions.

## Development workflow

For every feature: **design → write tests → implement**. No implementation without tests first.

## Directory overview

| Directory | Purpose |
|-----------|---------|
| `.kiro/steering/` | Agent steering files (always loaded) |
| `docs/` | Product docs, priority tiers, decisions, session logs |
| `HanaHou/` | App source code |
| `HanaHouTests/` | Unit tests |
| `HanaHouUITests/` | UI tests |

## Key rules

- Every directory must have an `AGENTS.md` — create one when creating a directory, update it when contents change.
- Offline-first: no network calls in P0 or P1.
- Core Data many-to-many for Card-Deck from day one.
- Record significant decisions in `docs/decisions.md`.
