---
inclusion: always
---
# Project Structure – HanaHou

```
HanaHou/
├── .kiro/steering/              ← Agent steering files (always loaded)
│   └── agent-modes/             ← PM, SDE, and Reviewer mode definitions
├── docs/                        ← Product docs, priority tiers, decisions, session logs
│   └── sessions/                ← Per-session development logs
├── HanaHou/                     ← App source code (SwiftUI views, Core Data models, etc.)
├── HanaHouTests/                ← Unit tests (XCTest)
├── HanaHouUITests/              ← UI tests (XCTest UI)
├── HanaHou.xcodeproj/           ← Xcode project configuration
├── AGENTS.md                    ← Root-level agent directives
└── README.md                    ← Human-facing project overview
```

## Directory purposes

- **`.kiro/steering/`** — Foundational context loaded into every agent interaction. Contains product overview, tech stack, this structure doc, steering rules, and prompt templates.
- **`.kiro/steering/agent-modes/`** — Mode-specific workflow definitions (PM, SDE, Reviewer). Access is restricted per mode: each agent reads only its own mode file. Only PM mode may read all three. See `steering.md` section 2 for the access rules.
- **`docs/`** — All product and technical documentation. Priority tier scopes, data model, decision log, open questions, roadmap.
- **`docs/sessions/`** — Chronological session logs capturing what was done, decided, and learned.
- **`HanaHou/`** — All app source code. SwiftUI views, Core Data model, persistence layer, and app entry point.
- **`HanaHouTests/`** — Unit tests for domain logic, data model, and non-UI behavior.
- **`HanaHouUITests/`** — UI tests for user-facing flows.

## Conventions

- Every directory has an `AGENTS.md` describing its contents and agent directives.
- One `README.md` at the project root for humans.
- Steering files use Kiro inclusion front matter (`inclusion: always`).
