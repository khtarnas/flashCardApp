---
inclusion: always
---
# Tech Stack & Constraints – HanaHou

## Language & Frameworks

- **Language:** Swift
- **UI Framework:** SwiftUI
- **Persistence:** Core Data
- **Platform:** iPadOS only (for now)
- **Minimum iOS version:** TBD (see `docs/open-questions.md`)

## Key Constraints

- **Offline-first:** All core features must work completely offline. No network calls in P0 or P1.
- **No third-party dependencies in P0.** Use Apple frameworks only until there's a clear need.
- **Single user:** No accounts, authentication, or sync.

## Future Technology (not yet in use)

- **Apple Pencil:** PencilKit framework for handwriting on cards (P1).
- **AI integration:** OpenAI API or local model — decision deferred. Will be behind a clean protocol/interface so the backend is swappable (P2+).
- **CloudKit:** Potential future sync layer. Core Data supports CloudKit, but not planned for early priorities.
- **Notifications:** `UserNotifications` framework for study reminders (future).

## Development Tools

- **IDE:** Xcode
- **Version control:** Git (GitHub, personal account)
- **AI assistant:** Kiro CLI
- **Testing:** XCTest (unit + UI tests, built into Xcode)

## Build & Run

- Open `HanaHou.xcodeproj` in Xcode
- Select an iPad simulator or connected iPad
- Build and run (⌘R)
- Run tests (⌘U)

## References

- [Apple PencilKit docs](https://developer.apple.com/documentation/pencilkit)
- [Core Data docs](https://developer.apple.com/documentation/coredata)
- [Storing PKDrawing in Core Data](https://stackoverflow.com/questions/69307314/storing-a-pkdrawing-object-to-core-data)
- [UserNotifications scheduling](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
