# Requirements Document

## Introduction

This document specifies the P0 requirements for card management in HanaHou, a personal iPadOS flashcard app. Card management covers creating, viewing, editing, and deleting Cards within a Deck, as well as an All Cards view that exposes every Card regardless of Deck membership (including Cards not currently attached to any Deck). Deck-level behavior is already specified in `.kiro/specs/deck-management/requirements.md` and is referenced here but not redefined.

Scope boundaries. In scope: Card CRUD within a Deck, a per-Deck Card list view, the All Cards view, and Card detail/edit. Out of scope for this spec: study mode, Apple Pencil, spaced repetition (SRS), multi-Deck Card assignment from the UI (P1 — the data model already supports many-to-many per D003), search, and filtering.

References: `docs/p0.md` for the P0 scope; `docs/data-model.md` for the Card entity schema; `docs/decisions.md` for D003 (many-to-many Card-Deck), D011 (plain text only for P0 Card content), D012 (delete-a-Deck detaches Cards; All Cards exposes Cards regardless of Deck membership), D021 (example-based tests in P0), D024 (`updatedAt` captured on edit, same pattern as Deck); `.kiro/specs/deck-management/design.md` for the four-layer architecture, the `DeckStore` protocol shape, and the "value types cross boundaries" convention this spec will extend with a parallel `CardStore`.

## Glossary

- **Card**: A flashcard identified by a UUID, containing a plain-text front and a plain-text back (per D011), a creation timestamp, and a last-updated timestamp (per D024). A Card may belong to zero or more Decks (per D003).
- **Deck**: A user-created collection of Cards, as defined in `.kiro/specs/deck-management/requirements.md`. Out of scope for this spec except where Card operations reference or affect Deck membership.
- **Orphaned_Card**: A Card whose set of associated Decks is empty. Orphaned Cards arise when every Deck a Card belonged to has been deleted (per D012), or when a Card is created in a context that does not attach it to any Deck.
- **Card_Draft**: An in-memory value type representing a Card's user-editable fields (front text, back text) that has not yet been persisted or applied.
- **Card_Snapshot**: An in-memory value type representing a persisted Card as it crosses the persistence boundary, including its id, front text, back text, creation timestamp, last-updated timestamp, and the identifiers of the Decks it is associated with.
- **Card_Manager**: The logical component that coordinates Card lifecycle operations (create, read, update, delete) and exposes Cards to views. Concretely this corresponds to the Card-related view models in the architecture.
- **Card_Store**: The persistence component that stores Card records and the Card-to-Deck association, and that enforces persistence-level constraints (id uniqueness, timestamps, relationship integrity). The Card_Store is the Card-side analogue of the Deck_Store defined in the deck-management spec.
- **Card_Editor**: The UI surface and validation component that handles user input for creating and editing a Card, including front-text and back-text validation.
- **Card_List_View**: The UI surface that displays a list of Cards scoped to a single Deck.
- **All_Cards_View**: The UI surface that displays every Card in the Card_Store regardless of Deck membership, including every Orphaned_Card.
- **Non-empty text**: A text value is non-empty if, after trimming leading and trailing whitespace and newline characters, at least one character remains.

## Requirements

### Requirement 1: Create a Card in a Deck

**User Story:** As a user, I want to create a new Card with a front and a back inside a specific Deck, so that I can build up study material for that Deck.

#### Acceptance Criteria

1. THE Card_Editor SHALL allow the user to enter a front text value and a back text value for a new Card.
2. WHEN the user submits a Card creation request from within a Deck, THE Card_Manager SHALL create a new Card in the Card_Store with the submitted front text and back text and SHALL associate the new Card with that Deck, provided that all validations in this requirement pass.
3. IF the user submits a Card creation request with a front text that is not Non-empty text, THEN THE Card_Editor SHALL reject the submission and display a validation message indicating that the front text is required.
4. IF the user submits a Card creation request with a back text that is not Non-empty text, THEN THE Card_Editor SHALL reject the submission and display a validation message indicating that the back text is required.
5. THE Card_Editor SHALL treat the front text and the back text as plain text only and SHALL NOT apply or preserve rich-text formatting, images, or media (per D011).
6. WHEN a Card is successfully created, THE Card_Store SHALL set the Card's createdAt attribute to the current time.
7. WHEN a Card is successfully created from within a Deck, THE Card_Store SHALL record an association between the new Card and that Deck such that subsequent queries scoped to that Deck return the new Card.

### Requirement 2: View Cards in a Deck

**User Story:** As a user, I want to see all of the Cards inside a specific Deck, so that I can review what is in that Deck and pick a Card to edit.

#### Acceptance Criteria

1. WHEN the user opens a Deck, THE Card_List_View SHALL display every Card in the Card_Store that is associated with that Deck.
2. THE Card_List_View SHALL display, for each Card, the Card's front text and back text.
3. THE Card_List_View SHALL display Cards in ascending order by createdAt, oldest first, with the Card's id as a deterministic tiebreaker when two Cards share the same createdAt value.
4. WHEN a Card associated with the displayed Deck is created, edited, or deleted, THE Card_List_View SHALL update to reflect the change.
5. WHILE the displayed Deck contains zero associated Cards, THE Card_List_View SHALL display an empty-state message indicating that the Deck contains no Cards and how to add one.

### Requirement 3: Edit a Card

**User Story:** As a user, I want to edit an existing Card's front and back text, so that I can correct mistakes and improve my study material over time.

#### Acceptance Criteria

1. THE Card_Editor SHALL allow the user to change the front text and back text of an existing Card.
2. WHEN the user submits a Card edit request, THE Card_Manager SHALL update the target Card in the Card_Store with the submitted front text and back text, provided that all validations in this requirement pass.
3. IF the user submits a Card edit request with a front text that is not Non-empty text, THEN THE Card_Editor SHALL reject the submission and display a validation message indicating that the front text is required.
4. IF the user submits a Card edit request with a back text that is not Non-empty text, THEN THE Card_Editor SHALL reject the submission and display a validation message indicating that the back text is required.
5. WHEN a Card is successfully edited, THE Card_Store SHALL preserve the Card's id, createdAt value, and Deck associations, and SHALL update the Card's updatedAt attribute to the current time (per D024).

### Requirement 4: Delete a Card

**User Story:** As a user, I want to delete a Card I no longer need, so that my Decks stay focused on what I am studying.

#### Acceptance Criteria

1. THE Card_Editor SHALL allow the user to initiate deletion of an existing Card.
2. WHEN the user confirms deletion of a Card, THE Card_Manager SHALL remove the target Card from the Card_Store.
3. WHEN a Card is deleted, THE Card_Store SHALL remove every association between the deleted Card and any Deck.
4. WHEN a Card is deleted, THE Card_Store SHALL NOT delete any Deck.

### Requirement 5: All Cards View

**User Story:** As a user, I want a single view that shows every Card in the app regardless of which Deck it belongs to, so that Cards that became Orphaned_Cards after a Deck deletion remain reachable (per D012).

#### Acceptance Criteria

1. WHEN the user selects the All_Cards_View entry from the Deck list, THE Card_Manager SHALL present the All_Cards_View.
2. THE All_Cards_View SHALL display every Card in the Card_Store regardless of Deck membership, including every Orphaned_Card.
3. THE All_Cards_View SHALL display, for each Card, the Card's front text and back text.
4. THE All_Cards_View SHALL display Cards in ascending order by createdAt, oldest first, with the Card's id as a deterministic tiebreaker when two Cards share the same createdAt value.
5. WHEN a Card is created, edited, or deleted anywhere in the app, THE All_Cards_View SHALL update to reflect the change.
6. WHILE the Card_Store contains zero Cards, THE All_Cards_View SHALL display an empty-state message indicating that no Cards exist yet.
7. THE All_Cards_View SHALL replace the existing AllCardsPlaceholderView such that selecting the All Cards entry in the Deck list no longer shows placeholder copy.

### Requirement 6: Orphaned Card Handling

**User Story:** As a user, I want Cards that are no longer attached to any Deck to remain accessible, so that deleting a Deck never silently loses Card content.

#### Acceptance Criteria

1. WHEN a Deck is deleted, THE Card_Store SHALL preserve every Card that was associated only with the deleted Deck and SHALL represent each such Card as an Orphaned_Card.
2. THE All_Cards_View SHALL include every Orphaned_Card (per Requirement 5, acceptance criterion 2).
3. WHERE a Card is an Orphaned_Card, THE Card_Editor SHALL still allow the user to edit the Card's front text and back text using the rules defined in Requirement 3.
4. WHERE a Card is an Orphaned_Card, THE Card_Editor SHALL still allow the user to delete the Card using the rules defined in Requirement 4.

### Requirement 7: Card Data Model and Persistence

**User Story:** As a developer, I want the Card entity's attributes, persistence rules, and change-notification contract to be defined, so that the persistence, validation, and UI layers behave consistently and the Card_Store is testable in isolation (per D021).

#### Acceptance Criteria

1. THE Card_Store SHALL represent each Card with an id of type UUID, a frontText of type String, a backText of type String, a createdAt of type Date, and an updatedAt of type Date, matching the Card entity defined in `docs/data-model.md`.
2. THE Card_Store SHALL model the Card-to-Deck relationship as many-to-many (per D003).
3. THE Card_Store SHALL provide an operation to fetch every Card in the store regardless of Deck membership.
4. THE Card_Store SHALL provide an operation to fetch every Card associated with a given Deck id.
5. THE Card_Store SHALL provide an operation to create a Card with a given front text, back text, and an initial set of associated Deck ids.
6. THE Card_Store SHALL provide an operation to update a Card's front text and back text by Card id, and SHALL bump the Card's updatedAt attribute to the current time on every successful update (per D024).
7. THE Card_Store SHALL provide an operation to delete a Card by Card id.
8. WHEN the Card_Store mutates any Card record or any Card-to-Deck association, THE Card_Store SHALL emit a change notification that view models can subscribe to in order to refresh their state.
9. IF the Card_Store is asked to update or delete a Card whose id does not exist in the store, THEN the Card_Store SHALL treat the operation as a no-op and SHALL NOT emit a change notification for that no-op.
10. THE Card_Store SHALL be defined as a protocol with at least two conforming implementations: one backed by Core Data for production use and one in-memory implementation usable by tests, matching the pattern established by Deck_Store in `.kiro/specs/deck-management/design.md`.

### Requirement 8: Replace the All Cards Placeholder

**User Story:** As a user, I want the "coming in the card-management spec" placeholder replaced with real functionality, so that All Cards is usable instead of informational.

#### Acceptance Criteria

1. THE Card_Manager SHALL route the All Cards entry from the Deck list to the All_Cards_View defined in Requirement 5 instead of to a placeholder view.
2. THE app SHALL NOT retain the AllCardsPlaceholderView in the running app's navigation once this spec is implemented.
3. THE AllCardsPlaceholderView source file SHALL be deleted from the project.

### Requirement 9: Testability and Test Strategy

**User Story:** As a developer, I want the Card CRUD behavior and the All Cards view model to be unit-testable without the simulator, so that I can follow TDD (per D007 and D021) and keep the test suite fast and deterministic.

#### Acceptance Criteria

1. THE Card_Manager SHALL depend on the Card_Store only through the protocol defined in Requirement 7, acceptance criterion 10.
2. THE Card_Store SHALL expose an injectable time source used for the Card's createdAt and updatedAt attributes, so that tests can assert on both deterministically.
3. THE Card_Manager SHALL be exercised by example-based XCTest unit tests (per D021) that use the in-memory Card_Store implementation and do not require a Core Data stack.
4. THE Core-Data-backed Card_Store SHALL be exercised by example-based XCTest unit tests that use an in-memory Core Data stack, matching the pattern established by `CoreDataDeckStoreTests` in `HanaHouTests/Persistence/`.
5. THE test coverage for this feature SHALL include, at minimum: create with empty front text rejected; create with empty back text rejected; create round-trip within a Deck returns the Card in that Deck's list and in All Cards; create sets both createdAt and updatedAt from the injected time source; edit round-trip preserves id, createdAt, and Deck associations; edit bumps updatedAt to the current time from the injected time source while preserving createdAt; delete removes the Card from every Deck and from All Cards; delete of a Card in two Decks removes the Card from both Decks without deleting the Decks; a Card becomes an Orphaned_Card when its last associated Deck is deleted; ordering by createdAt ascending with id as tiebreaker for both the per-Deck list and All Cards.
