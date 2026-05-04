# Roadmap – HanaHou

## Priority Tiers

| Tier | Theme | Status |
|------|-------|--------|
| P0 | Core flashcards (decks, cards, study mode) | 🟡 In progress |
| P1 | Study persistence + UX polish | 🔴 Not started |
| P2 | SRS (spaced repetition) | 🔴 Not started |
| P3 | Rich content + layout | 🔴 Not started |
| P4 | AI integration | 🔴 Not started |
| P5 | Word-count tracking, study logging, conversational topics | 🔴 Not started |

## Feature Backlog

### P0 — Must Have
- Deck CRUD (create, read, update, delete)
- Card CRUD within decks
- "All Cards" system deck (undeletable, shows all cards)
- Study mode: flip cards, self-grade (3 categories), sequential ordering
- Stack navigation (NavigationStack), portrait only

### P1 — Study Persistence + UX Polish
- StudyEvent persistence (record per-card review outcomes to Core Data)
- Study session summary screen with per-session statistics
- Study mode enhancements (shuffle option, user-selectable ordering)
- Study from All Cards view (study every card regardless of deck membership)
- Homepage / welcome screen (landing page → Decks; later → Stats, AI practice)
- Create cards from All Cards view (orphan creation)
- Orphan section in All Cards (grouped at top, visually separated)
- Language labels on card editor ("Front (Japanese)" / "Back (English)")
- Search/filter for cards and decks
- Deck deletion button in DeckEditorView (consistency with CardEditorView)

### P2 — SRS
- Spaced repetition scheduling algorithm (builds on P1 StudyEvent data)
- Data retention limits (last N events per card)
- Study session entity (historical tracking across sessions)
- Card-to-deck many-to-many in UI

### P3 — Rich Content + Layout
- Apple Pencil drawing on cards (PencilKit)
- Collapsible sidebar navigation (NavigationSplitView)
- Landscape orientation support

### P4 — AI Integration
- Clean protocol/interface for AI backend
- Support for remote API (OpenAI) or local model
- AI-assisted card generation or study suggestions
- Voice-to-flashcard: record audio message → AI agent generates flashcard(s)

### P5 — Tracking & Logging
- Word count tracker ("you know at least X words")
- Conversational topic suggestions based on known vocabulary
- Study logging with external resources (Duolingo, textbooks, podcasts, etc.)
- Dialogue feature with character/romanization options

### Unscheduled / Ideas
- Study modes: "Free Study" (confidence-based self-grading) vs "Test Mode" (outcome-based grading, e.g., "Got it" / "Close" / "Missed")
- Statistics / analytics dashboard (broader vision — "data about learning is inspiring")
- Notifications / study reminders
- Import/export (CSV, Anki format)
- macOS support
- App Store distribution
- Script to populate local database for testing
- Configurable deck deletion behavior (delete cards vs detach)
