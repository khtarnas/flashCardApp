# Requirements Document

## Introduction

This document specifies the P0 requirements for study mode in HanaHou, a personal iPadOS flashcard app. Study mode is the third and final P0 feature: with deck management and card management already implemented, the user can now start a study session from a Deck, flip Cards front-to-back, self-grade each Card using three categories (per D008), and advance sequentially through the Deck (per D009) until the session is complete (per D010).

Scope boundaries. In scope: starting a session from a Deck, presenting one Card at a time (front first), flipping to reveal the back, self-grading with three categories, advancing to the next Card, sequential ordering for P0, and a completion screen that returns the user to the home screen. Out of scope: spaced repetition (P2), shuffle ordering (P1 — the ordering-strategy protocol defined here must be swappable to support it), study statistics and history (P1), `StudyEvent` persistence (P1 per D039 — study state is ephemeral/in-memory for P0), studying from the All Cards view (deferred to P1+ per D041, not permanently excluded), Apple Pencil interactions during study (P1+), and mid-session editing of Cards.

References: `docs/p0.md` for the P0 scope (study mode is the last remaining item); `docs/decisions.md` for D008 (three self-grading categories, designed to be mutable), D009 (sequential ordering for P0, swappable strategy), D010 (study completion returns to home screen in P0; summary screen is a future feature), D021 (example-based XCTest in P0, not property-based), D036 (self-grade label set resolved to confidence-oriented Option A), D039 (`StudyEvent` persistence moves from P2 to P1; P0 remains ephemeral), D041 (study from All Cards is deferred from P0, not permanently excluded); `.kiro/specs/deck-management/design.md` and `.kiro/specs/card-management/design.md` for the four-layer architecture (Models → Domain → Persistence → ViewModels → Views), the value-types-across-boundaries convention, the `DeckSnapshot` and `CardSnapshot` types, the `CardStore` protocol, and the `CardOrderingStrategy` protocol this spec will reuse; `docs/data-model.md` for the current Card entity (no `StudyEvent` yet — that's a P1 concern per D039).

### Open question surfaced by this spec

**Self-grading category labels (referenced in Req 4 AC 1). RESOLVED — D036: Option A.** D008 fixes the number of categories at three and requires that they be mutable, but the exact labels were TBD in this document. Three candidate label sets were presented:

- **A. Confidence-oriented (the original D008 wording):** "I know it", "I'm close", "No idea". **← chosen, per D036.**
- **B. Outcome-oriented:** "Got it", "Close", "Missed". (Retained for a future "Test Mode".)
- **C. Terse/neutral:** "Know", "Maybe", "No".

Per D036, Option A is the P0 label set. Req 4 and Req 9 remain correct as written: exactly three categories exist, they are modeled as a finite enum, the enum is the single point of change if the labels are renamed or extended, and rendering uses the enum's human-readable label from one place.

## Glossary

- **Card**: A flashcard as defined in `.kiro/specs/card-management/requirements.md`, with plain-text front and plain-text back content, identified by a UUID.
- **Deck**: A user-created collection of Cards as defined in `.kiro/specs/deck-management/requirements.md`. In this spec, the Deck is the scope of a study session.
- **Card_Snapshot**: The immutable value type defined in `.kiro/specs/card-management/design.md` that carries a persisted Card across the persistence boundary. Study mode consumes `CardSnapshot` values — it does not see `NSManagedObject`.
- **Study_Session**: An in-memory, ephemeral unit of study. A Study_Session is scoped to exactly one Deck, contains an ordered sequence of Card_Snapshot values drawn from that Deck at the moment the session starts, and tracks which Card the user is currently viewing, whether that Card's back is revealed, and the per-Card self-grade the user has assigned so far. A Study_Session is not persisted to Core Data in P0 (per `docs/p0.md` and D010); closing the app or returning to the home screen discards the session.
- **Study_Manager**: The logical component that coordinates a Study_Session's lifecycle (start, flip, grade, advance, complete) and exposes state to the study view. Concretely this corresponds to a study-mode view model in the layered architecture.
- **Study_View**: The UI surface that displays the current Card's front, allows the user to flip to the back, displays the three Self_Grade options after the flip, and advances to the next Card on grade selection.
- **Study_Completion_View**: The UI surface displayed after every Card in the Study_Session has been graded. In P0 this view offers a single action to return to the home screen (per D010). No statistics are displayed.
- **Self_Grade**: A value from a finite set of exactly three categories (per D008) the user assigns to a Card after revealing the back. The three categories are modeled as a Swift enum with a human-readable label derived from the enum. Per D036 the P0 labels are confidence-oriented ("I know it", "I'm close", "No idea"); the enum is the single point of change so a future priority can rename, add, or remove categories (per D008's "designed to be mutable").
- **Card_Ordering_Strategy**: The existing `CardOrderingStrategy` protocol defined in `HanaHou/Domain/CardOrderingStrategy.swift` and `.kiro/specs/card-management/design.md`. Study mode reuses this protocol (rather than introducing a new one) so that sequential ordering in P0 and shuffle ordering in P1 share a single abstraction. The P0 default for study mode is the existing `CardCreationDateAscendingOrdering` — the same sequential order users see in the Card list.
- **Card_Position**: The zero-based index of the currently displayed Card within the Study_Session's ordered Card sequence. A Study_Session with N Cards has valid Card_Position values 0 through N−1.
- **Front_Revealed_State**: The phase of the currently displayed Card in which only the Card's front text is visible and the Card has not yet been graded.
- **Back_Revealed_State**: The phase of the currently displayed Card in which both the front and back text are visible and the three Self_Grade options are available for selection.
- **Completed_State**: The phase of a Study_Session after the user has graded every Card, in which the Study_Completion_View is presented.
- **Empty_Deck_State**: The phase of a Study_Session whose source Deck contained zero Cards at the moment the session started. No Card is displayed; the Study_View surfaces an empty-state message and an action to return to the Deck list.

## Requirements

### Requirement 1: Start a Study Session from a Deck

**User Story:** As a user, I want to start a study session for a specific Deck, so that I can practice the Cards that Deck contains.

#### Acceptance Criteria

1. THE Study_View SHALL provide an entry point, reachable from the per-Deck Card list view, that starts a Study_Session scoped to the Deck currently being viewed.
2. WHEN the user starts a Study_Session for a Deck, THE Study_Manager SHALL load every Card_Snapshot currently associated with that Deck from the Card store into the Study_Session.
3. WHEN the user starts a Study_Session for a Deck, THE Study_Manager SHALL order the loaded Card_Snapshot values using the Card_Ordering_Strategy configured for the Study_Session and SHALL store the ordered sequence as the Study_Session's ordered Card sequence.
4. WHERE the P0 Card_Ordering_Strategy for study mode is active, THE Card_Ordering_Strategy SHALL produce the same sequential order used by the per-Deck Card list — ascending by Card createdAt, oldest first, with the Card's id as a deterministic tiebreaker.
5. THE Study_Manager SHALL accept the Card_Ordering_Strategy as a swappable component so that the P1 shuffle strategy can replace the P0 sequential strategy without changes to the Study_View.
6. WHEN a Study_Session with at least one Card_Snapshot begins, THE Study_Manager SHALL set the Card_Position to 0 and SHALL set the Study_Session's phase to Front_Revealed_State.
7. WHEN a Study_Session begins, THE Study_View SHALL display the Card at the current Card_Position using the rules in Requirement 2.
8. THE Study_Manager SHALL treat the Study_Session's ordered Card sequence as a snapshot taken at the moment the session started and SHALL NOT modify that sequence if Cards are added to, edited in, or removed from the source Deck during the session.
9. IF the user starts a Study_Session for a Deck that contains zero Cards at the moment the session starts, THEN THE Study_Manager SHALL set the Study_Session's phase to Empty_Deck_State and SHALL NOT attempt to display any Card.
10. WHILE the Study_Session is in the Empty_Deck_State, THE Study_View SHALL display an empty-state message indicating that the Deck contains no Cards to study and SHALL provide an action that returns the user to the Deck list.

### Requirement 2: Display the Current Card Front

**User Story:** As a user, I want to see only the front of the current Card first, so that I can recall the answer from memory before revealing it.

#### Acceptance Criteria

1. WHILE the Study_Session is in the Front_Revealed_State, THE Study_View SHALL display the frontText of the Card at the current Card_Position.
2. WHILE the Study_Session is in the Front_Revealed_State, THE Study_View SHALL NOT display the backText of the Card at the current Card_Position.
3. WHILE the Study_Session is in the Front_Revealed_State, THE Study_View SHALL NOT display the three Self_Grade options.
4. WHILE the Study_Session is in the Front_Revealed_State, THE Study_View SHALL provide a visible, tappable affordance that reveals the back of the current Card.
5. THE Study_View SHALL display the current Card_Position and the total count of Cards in the Study_Session's ordered Card sequence in a progress indicator (for example, "3 of 10").

### Requirement 3: Flip to Reveal the Card Back

**User Story:** As a user, I want to flip the Card to reveal the back, so that I can check my answer.

#### Acceptance Criteria

1. WHEN the user activates the reveal affordance described in Requirement 2 acceptance criterion 4, THE Study_Manager SHALL set the Study_Session's phase from Front_Revealed_State to Back_Revealed_State for the Card at the current Card_Position.
2. WHILE the Study_Session is in the Back_Revealed_State, THE Study_View SHALL display both the frontText and the backText of the Card at the current Card_Position.
3. WHILE the Study_Session is in the Back_Revealed_State, THE Study_View SHALL display the three Self_Grade options defined in Requirement 4.
4. WHILE the Study_Session is in the Back_Revealed_State, THE Study_View SHALL NOT display the reveal affordance described in Requirement 2 acceptance criterion 4.
5. IF the user activates the reveal affordance while the Study_Session is already in the Back_Revealed_State for the current Card_Position, THEN THE Study_Manager SHALL treat the activation as a no-op and SHALL NOT change the Study_Session's phase.

### Requirement 4: Self-Grade the Current Card

**User Story:** As a user, I want to self-grade how well I recalled the current Card using three distinct categories, so that I can reflect on my performance and lay the groundwork for future spaced repetition (P2, built on P1 `StudyEvent` data per D039).

#### Acceptance Criteria

1. THE Study_View SHALL display exactly three Self_Grade options corresponding one-to-one with the cases of the Self_Grade enum defined in the Glossary.
2. WHERE the Study_Session is in the Back_Revealed_State, THE Study_View SHALL make each of the three Self_Grade options selectable by the user.
3. WHEN the user selects a Self_Grade option, THE Study_Manager SHALL record that Self_Grade value against the Card at the current Card_Position in the Study_Session's in-memory state.
4. WHEN the user selects a Self_Grade option, THE Study_Manager SHALL advance to the next Card using the rules in Requirement 5.
5. THE Study_Manager SHALL keep the recorded Self_Grade values in the Study_Session's in-memory state only and SHALL NOT persist them to Core Data in P0.
6. THE Self_Grade enum SHALL be the single source of truth for the set of categories and the single point of change if the categories are renamed, added to, or removed in a future priority (per D008).

### Requirement 5: Advance to the Next Card

**User Story:** As a user, I want the app to automatically advance to the next Card after I grade the current one, so that my study flow stays uninterrupted.

#### Acceptance Criteria

1. WHEN the user selects a Self_Grade option while the Study_Session is in the Back_Revealed_State and the current Card_Position is less than the highest valid Card_Position, THE Study_Manager SHALL increment the Card_Position by 1 and SHALL set the Study_Session's phase to Front_Revealed_State for the new Card_Position.
2. WHEN the user selects a Self_Grade option while the Study_Session is in the Back_Revealed_State and the current Card_Position is equal to the highest valid Card_Position, THE Study_Manager SHALL set the Study_Session's phase to Completed_State using the rules in Requirement 6.
3. THE Study_Manager SHALL present each Card at each Card_Position exactly once per Study_Session.
4. THE Study_Manager SHALL NOT allow the user to navigate backward to a previously graded Card within the same Study_Session in P0.

### Requirement 6: Complete the Study Session

**User Story:** As a user, I want a clear indication that I have finished the Study_Session and a way to return to the home screen, so that I know when to stop and can pick my next activity.

#### Acceptance Criteria

1. WHEN the Study_Manager sets the Study_Session's phase to Completed_State, THE Study_View SHALL present the Study_Completion_View.
2. THE Study_Completion_View SHALL display a message indicating that the user has finished studying the source Deck.
3. THE Study_Completion_View SHALL provide a single action that returns the user to the home screen (per D010).
4. THE Study_Completion_View SHALL NOT display study statistics, history, or per-grade counts in P0 (per D010 — the summary screen is a future feature).
5. WHEN the user activates the return action described in acceptance criterion 3, THE Study_Manager SHALL dismiss the Study_Completion_View and SHALL return the user to the Deck list root of the navigation stack.
6. WHEN the Study_Completion_View is dismissed, THE Study_Manager SHALL discard the Study_Session and all of its in-memory state, including the ordered Card sequence, the recorded Self_Grade values, and the Card_Position.

### Requirement 7: Exit a Study Session Before Completion

**User Story:** As a user, I want to abandon a Study_Session at any time, so that I am not forced to finish every Card before doing something else.

#### Acceptance Criteria

1. WHILE the Study_Session is in the Front_Revealed_State or the Back_Revealed_State, THE Study_View SHALL provide a visible, tappable affordance that exits the Study_Session without completing it.
2. WHEN the user activates the exit affordance described in acceptance criterion 1, THE Study_Manager SHALL discard the Study_Session and all of its in-memory state.
3. WHEN the user activates the exit affordance described in acceptance criterion 1, THE Study_Manager SHALL return the user to the Card list of the source Deck.
4. THE Study_Manager SHALL NOT persist any Self_Grade values recorded during a Study_Session that the user exits before completion.

### Requirement 8: Navigation and Orientation

**User Story:** As a user, I want study mode to follow the same navigation and orientation conventions as the rest of P0, so that the app feels consistent.

#### Acceptance Criteria

1. THE Study_View SHALL be presented via the existing stack navigation (per D013) rooted at the Deck management root view.
2. THE Study_View SHALL be reachable from the per-Deck Card list view and SHALL NOT be reachable from the All Cards view in P0.
3. THE app SHALL continue to lock the interface orientation to portrait orientation while the Study_View is active (per D014 and the deck-management orientation-lock requirement).
4. THE Study_Manager SHALL confine any study-mode-specific orientation configuration to the single orientation-lock point of change established by the deck-management feature, if any is required.

### Requirement 9: Study Session State Model (Ephemeral, In-Memory)

**User Story:** As a developer, I want the Study_Session's state model, ordering-strategy contract, and self-grade enum defined precisely, so that the persistence, domain, view-model, and view layers behave consistently and the state model is testable in isolation (per D021).

#### Acceptance Criteria

1. THE Study_Manager SHALL represent a Study_Session as an in-memory value type or reference type that contains: the source Deck's id; the ordered sequence of Card_Snapshot values loaded at session start; the current Card_Position; the Study_Session's phase (Front_Revealed_State, Back_Revealed_State, Completed_State, or Empty_Deck_State); and a mapping from each graded Card's id to its recorded Self_Grade value.
2. THE Study_Manager SHALL NOT introduce any new Core Data entities in P0 (per `docs/p0.md` — `StudyEvent` is a P1 concern per D039).
3. THE Study_Manager SHALL obtain the Study_Session's initial ordered Card sequence by calling the existing `CardStore.fetchInDeck(deckId:)` operation defined in `.kiro/specs/card-management/design.md` and then applying the injected Card_Ordering_Strategy.
4. THE Study_Manager SHALL depend on the `CardStore` protocol only — not on any concrete `CardStore` implementation — so that view-model tests can drive the Study_Manager with the existing in-memory `CardStore` test double.
5. THE Study_Manager SHALL depend on the `CardOrderingStrategy` protocol only — not on any concrete strategy implementation — so that tests can substitute a stub strategy to assert on the order passed through to the view.
6. THE Self_Grade enum SHALL be defined with exactly three cases corresponding to the three categories specified in D008, SHALL conform to `Equatable` and `CaseIterable` so the Study_View can render the three options from the enum, and SHALL expose a human-readable label for each case from a single point.

### Requirement 10: Testability and Test Strategy

**User Story:** As a developer, I want study mode to be unit-testable without the simulator and without a Core Data stack, so that I can follow TDD (per D007 and D021) and keep the test suite fast and deterministic.

#### Acceptance Criteria

1. THE Study_Manager SHALL be exercised by example-based XCTest unit tests (per D021) that use the existing in-memory `CardStore` implementation and a stub or concrete `CardOrderingStrategy`, and that do not require a Core Data stack.
2. THE Self_Grade enum and its human-readable labels SHALL be exercised by example-based XCTest unit tests that assert on each of the three cases.
3. THE test coverage for this feature SHALL include, at minimum:
   1. Starting a Study_Session for a Deck with zero Cards places the session in the Empty_Deck_State and displays no Card.
   2. Starting a Study_Session for a Deck with one or more Cards places the session in the Front_Revealed_State at Card_Position 0.
   3. Starting a Study_Session applies the injected Card_Ordering_Strategy to the Cards returned from `CardStore.fetchInDeck(deckId:)` and uses the resulting order as the Study_Session's ordered Card sequence (verified with a stub strategy that returns a known order).
   4. Starting a Study_Session with the P0 strategy and a known set of Cards with distinct and tied createdAt values produces the same ordering as the per-Deck Card list for the same Cards.
   5. Flipping a Card in the Front_Revealed_State transitions the session to the Back_Revealed_State for the same Card_Position.
   6. Flipping a Card in the Back_Revealed_State is a no-op and leaves the Card_Position and phase unchanged.
   7. Selecting a Self_Grade in the Back_Revealed_State records that Self_Grade against the current Card's id in the session's grade map.
   8. Selecting a Self_Grade while the current Card_Position is less than the highest valid Card_Position advances the Card_Position by 1 and sets the phase to Front_Revealed_State.
   9. Selecting a Self_Grade while the current Card_Position equals the highest valid Card_Position sets the phase to Completed_State.
   10. The Study_Session's ordered Card sequence does not change when Cards are added to, edited in, or removed from the source Deck during the session (the session uses the snapshot taken at start).
   11. Exiting a Study_Session via the exit affordance discards all in-memory state and does not persist any Self_Grade values.
   12. The Self_Grade enum has exactly three cases and each case has a distinct, non-empty human-readable label.
