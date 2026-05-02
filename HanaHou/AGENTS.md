# AGENTS.md — HanaHou/ (App Source)

Main application source code for HanaHou.

## Current contents

| File | Purpose |
|------|---------|
| `HanaHouApp.swift` | App entry point, injects Core Data context |
| `ContentView.swift` | Main view (currently Xcode template — to be replaced) |
| `Persistence.swift` | Core Data stack setup (PersistenceController) |
| `HanaHou.xcdatamodeld/` | Core Data model definition |
| `Assets.xcassets/` | App icons and color assets |

## Directives

- All source code goes in this directory or its subdirectories.
- When adding subdirectories (e.g., `Models/`, `Views/`, `Services/`), create an `AGENTS.md` in each.
- Follow SwiftUI patterns and conventions.
- Core Data entities must match `docs/data-model.md`.
- No network calls in P0 or P1.
