# Roadmap – HanaHou

## Priority Tiers

| Tier | Theme | Status |
|------|-------|--------|
| P0 | Core flashcards (decks, cards, study mode) | 🟡 In progress |
| P1 | Apple Pencil + study enhancements | 🔴 Not started |
| P2 | SRS (spaced repetition) | 🔴 Not started |
| P3 | AI integration | 🔴 Not started |
| P4 | Word-count tracking, study logging, conversational topics | 🔴 Not started |

## Feature Backlog

### P0 — Must Have
- Deck CRUD (create, read, update, delete)
- Card CRUD within decks
- "All Cards" system deck (undeletable, shows all cards)
- Study mode: flip cards, self-grade (3 categories), sequential ordering
- Stack navigation (NavigationStack), portrait only

### P1 — Should Have
- Apple Pencil drawing on cards (PencilKit)
- Card-to-deck many-to-many in UI
- Study mode enhancements (shuffle option, user-selectable ordering)
- Study session summary screen with statistics
- Collapsible sidebar navigation (NavigationSplitView)
- Landscape orientation support
- Homepage / welcome screen (landing page → Decks; later → Stats, AI practice)
- Create cards from All Cards view (orphan creation)
- Orphan section in All Cards (grouped at top, visually separated)
- Language labels on card editor ("Front (Japanese)" / "Back (English)")
- Search/filter for cards and decks
- Deck deletion button in DeckEditorView (consistency with CardEditorView)

### P2 — SRS
- StudyEvent entity (records per-card review outcomes)
- Spaced repetition scheduling algorithm
- Data retention limits (last N events per card)
- Study session entity

### P3 — AI Integration
- Clean protocol/interface for AI backend
- Support for remote API (OpenAI) or local model
- AI-assisted card generation or study suggestions
- Voice-to-flashcard: record audio message → AI agent generates flashcard(s)

### P4 — Tracking & Logging
- Word count tracker ("you know at least X words")
- Conversational topic suggestions based on known vocabulary
- Study logging with external resources (Duolingo, textbooks, podcasts, etc.)
- Dialogue feature with character/romanization options

### Unscheduled / Ideas
- Statistics / analytics dashboard (broader vision — "data about learning is inspiring")
- Notifications / study reminders
- Import/export (CSV, Anki format)
- macOS support
- App Store distribution
- Script to populate local database for testing
- Configurable deck deletion behavior (delete cards vs detach)
