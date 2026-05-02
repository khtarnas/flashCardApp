# Requirements Document

## Introduction

This document specifies the P0 requirements for deck management in HanaHou, a personal iPadOS flashcard app. Deck management covers listing, creating, editing, and deleting user-created Decks, as well as the system-managed "All Cards" view that exposes every Card regardless of Deck membership. Card-level behavior, Study Mode behavior, and Apple Pencil support are out of scope and are covered by other specs. See `docs/p0.md` for the broader P0 scope and `docs/decisions.md` for referenced decisions (D003, D009, D012, D013, D014).

## Glossary

- **Deck**: A user-created collection of Cards, identified by a name and associated with a front Language and a back Language.
- **Card**: A flashcard with plain-text front and back content (per D011). Out of scope for this spec except where Deck operations affect Card associations.
- **Language**: A value from the Language enum defined in `docs/data-model.md`, including an `.other` case.
- **Deck_Manager**: The logical component that coordinates Deck lifecycle operations (create, read, update, delete) and exposes Decks to views.
- **Deck_List_View**: The UI surface that displays the list of Decks and the All_Cards_View entry to the user.
- **Deck_Editor**: The UI surface and validation component that handles user input for creating and editing a Deck, including name validation.
- **Deck_Store**: The persistence component that stores Deck records and enforces persistence-level constraints (uniqueness, reservation, timestamps).
- **Deck_Ordering_Strategy**: A swappable component that determines the order in which user-created Decks are presented in the Deck_List_View. In P0 the strategy orders user-created Decks by creation date, oldest first. The strategy follows the swappable pattern established in D009 for card ordering.
- **All_Cards_View**: The system-managed view that displays every Card regardless of Deck membership (per D012). The All_Cards_View is represented by a dedicated list entry in the Deck_List_View and is not a user-editable Deck.
- **Unique name**: A Deck name comparison rule used for the uniqueness constraint between user-created Decks. Two names are considered equal if, after trimming leading and trailing whitespace, they are byte-for-byte equal under a case-sensitive comparison.
- **Reserved name**: A Deck name that is not permitted for user-created Decks. In P0 the only reserved name is the literal string "All Cards". A user-supplied name matches a reserved name if, after trimming leading and trailing whitespace, it is equal to the reserved name under a case-insensitive comparison. The reserved-name check is independent of the Unique name check.
- **Portrait orientation**: The device orientation in which the app's vertical axis is aligned with the device's long axis.

## Requirements

### Requirement 1: View the List of Decks

**User Story:** As a user, I want to see all of my Decks in one list, so that I can pick one to study or edit.

#### Acceptance Criteria

1. THE Deck_List_View SHALL display every user-created Deck stored in the Deck_Store.
2. THE Deck_List_View SHALL display, for each user-created Deck, the Deck's name, front Language, and back Language.
3. THE Deck_List_View SHALL display an All_Cards_View entry in addition to the user-created Decks.
4. THE Deck_List_View SHALL display the All_Cards_View entry at a fixed position in the list that is independent of the Deck_Ordering_Strategy.
5. THE Deck_List_View SHALL display user-created Decks in the order produced by the Deck_Ordering_Strategy.
6. WHERE the P0 Deck_Ordering_Strategy is active, THE Deck_Ordering_Strategy SHALL order user-created Decks by creation date, oldest first.
7. THE Deck_Manager SHALL expose the Deck_Ordering_Strategy as a swappable component so that the ordering rule for user-created Decks can be replaced in a future priority without changing the Deck_List_View's contract.
8. WHEN a user-created Deck is added, renamed, or deleted, THE Deck_List_View SHALL update to reflect the change.

### Requirement 2: Create a Deck

**User Story:** As a user, I want to create a new Deck with a name and a front and back Language, so that I can organize Cards for a specific study topic.

#### Acceptance Criteria

1. THE Deck_Editor SHALL allow the user to enter a Deck name, select a front Language, and select a back Language.
2. THE Deck_Editor SHALL require the front Language and the back Language to be values from the Language enum.
3. WHEN the user submits a Deck creation request, THE Deck_Manager SHALL create a new Deck in the Deck_Store using the submitted name, front Language, and back Language, provided that all validations in this requirement pass.
4. IF the user submits a Deck creation request with a name that, after trimming leading and trailing whitespace, is an empty string, THEN THE Deck_Editor SHALL reject the submission and display a validation message indicating that the name is required.
5. IF the user submits a Deck creation request with a name that matches the Unique name of an existing user-created Deck, THEN THE Deck_Editor SHALL reject the submission and display a validation message indicating that the name is already in use.
6. IF the user submits a Deck creation request with a name that matches a Reserved name, THEN THE Deck_Editor SHALL reject the submission and display a validation message indicating that the name is reserved.
7. WHEN a Deck is successfully created, THE Deck_Store SHALL set the Deck's createdAt attribute to the current time.
8. WHEN a Deck is successfully created, THE Deck_Store SHALL set the Deck's updatedAt attribute equal to the Deck's createdAt value.

### Requirement 3: Edit a Deck

**User Story:** As a user, I want to edit a Deck's name and Languages, so that I can correct mistakes and adapt Decks as my study needs change.

#### Acceptance Criteria

1. THE Deck_Editor SHALL allow the user to change the name, front Language, and back Language of an existing user-created Deck.
2. WHEN the user submits a Deck edit request, THE Deck_Manager SHALL update the target Deck in the Deck_Store with the submitted values, provided that all validations in this requirement pass.
3. IF the user submits a Deck edit request with a name that, after trimming leading and trailing whitespace, is an empty string, THEN THE Deck_Editor SHALL reject the submission and display a validation message indicating that the name is required.
4. IF the user submits a Deck edit request with a name that matches the Unique name of a different existing user-created Deck, THEN THE Deck_Editor SHALL reject the submission and display a validation message indicating that the name is already in use.
5. IF the user submits a Deck edit request with a name that matches a Reserved name, THEN THE Deck_Editor SHALL reject the submission and display a validation message indicating that the name is reserved.
6. WHEN a Deck is successfully edited, THE Deck_Store SHOULD set the Deck's updatedAt attribute to the current time.

### Requirement 4: Delete a Deck

**User Story:** As a user, I want to delete a Deck I no longer need, so that my Deck list stays focused on what I am studying, without losing the underlying Cards.

#### Acceptance Criteria

1. THE Deck_Editor SHALL allow the user to initiate deletion of an existing user-created Deck.
2. WHEN the user confirms deletion of a user-created Deck, THE Deck_Manager SHALL remove the target Deck from the Deck_Store.
3. WHEN a user-created Deck is deleted, THE Deck_Manager SHALL detach the deleted Deck from every Card previously associated with the deleted Deck without deleting any Card (per D012).
4. IF the user initiates deletion of the All_Cards_View entry, THEN THE Deck_Manager SHALL reject the deletion and display a message indicating that the All_Cards_View entry cannot be deleted.

### Requirement 5: Deck Name Validation Rules

**User Story:** As a user, I want consistent rules for Deck names, so that I cannot create names that collide with existing Decks or with the reserved All Cards name.

#### Acceptance Criteria

1. THE Deck_Editor SHALL treat a Deck name as invalid if, after trimming leading and trailing whitespace, the name is an empty string.
2. THE Deck_Editor SHALL treat a Deck name as invalid if the name matches the Unique name of any other user-created Deck in the Deck_Store.
3. THE Deck_Editor SHALL treat a Deck name as invalid if the name matches a Reserved name.
4. THE Deck_Editor SHALL apply the rules in acceptance criteria 1, 2, and 3 to both Deck creation submissions and Deck edit submissions.
5. THE Deck_Editor SHALL display a distinct validation message for each of the empty-name, duplicate-name, and reserved-name rejection cases.
6. THE Deck_Editor SHALL compare a user-supplied Deck name to every Reserved name using the Reserved name comparison rule defined in the Glossary, which trims leading and trailing whitespace from the user-supplied name and then compares case-insensitively.

### Requirement 6: Deck Data Model

**User Story:** As a developer, I want the Deck entity's attributes and constraints to be defined, so that persistence and validation behave consistently across the app.

#### Acceptance Criteria

1. THE Deck_Store SHALL represent each Deck with an id of type UUID, a name of type String, a front Language of type Language, a back Language of type Language, a createdAt of type Date, and an updatedAt of type Date.
2. THE Deck_Store SHALL enforce that the name of every user-created Deck is unique under the Unique name comparison rule defined in the Glossary.
3. THE Deck_Store SHALL enforce that the name of every user-created Deck does not match any Reserved name, where matching is defined by the Reserved name comparison rule in the Glossary.
4. WHEN a Deck is created, THE Deck_Store SHALL set the Deck's createdAt attribute to the current time and SHALL set the Deck's updatedAt attribute equal to the Deck's createdAt value.
5. WHEN a Deck is successfully edited, THE Deck_Store SHOULD set the Deck's updatedAt attribute to the current time.
6. THE Deck_Store SHALL model the Card-to-Deck relationship as many-to-many (per D003).
7. WHERE the P0 UI does not display the updatedAt attribute, THE Deck_Store SHALL still persist the updatedAt attribute so that future priorities can consume it (for example, to sort by most recently modified).

### Requirement 7: Navigation and Orientation

**User Story:** As a user, I want a predictable navigation flow and a stable orientation, so that deck management feels consistent on iPad.

#### Acceptance Criteria

1. THE Deck_Manager SHALL present deck management screens using stack navigation (per D013).
2. THE Deck_Manager SHALL support Portrait orientation.
3. THE app SHALL lock the interface orientation to Portrait orientation.
4. THE app SHALL suppress rotation to landscape orientation while any deck management screen is active.
5. THE app SHALL confine the orientation lock configuration to a single point of change, so that the lock can be removed when landscape support is added in a future priority.

### Requirement 8: All Cards System View

**User Story:** As a user, I want a built-in way to see every Card regardless of Deck, so that Cards detached from deleted Decks remain accessible.

#### Acceptance Criteria

1. THE Deck_List_View SHALL always display an All_Cards_View entry (per D012).
2. WHEN the user selects the All_Cards_View entry, THE Deck_Manager SHALL present a view that displays every Card in the Deck_Store regardless of Deck membership.
3. IF the user initiates a rename of the All_Cards_View entry, THEN THE Deck_Editor SHALL reject the rename and display a message indicating that the All_Cards_View entry cannot be renamed.
4. IF the user initiates a deletion of the All_Cards_View entry, THEN THE Deck_Editor SHALL reject the deletion and display a message indicating that the All_Cards_View entry cannot be deleted.
5. THE Deck_Store SHALL represent the All_Cards_View as a system concept rather than as a user-created Deck record (per `docs/p0.md`).
