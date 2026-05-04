//
//  StudySession.swift
//  HanaHou
//
//  Feature: study-mode
//

import Foundation

/// Ephemeral, in-memory state of an ongoing study session. Corresponds
/// to the Req 9 "Study_Session" state model. **Not persisted** — P0
/// study state lives entirely in memory (Req 9 AC 2 per D039;
/// `StudyEvent` persistence is deferred to P1).
///
/// A `StudySession` is fully described by its five fields; the `phase`
/// discriminates which fields the view should read. Holding the state
/// in a plain struct — rather than scattering it across view-model
/// properties — keeps the state machine's invariants local and
/// inspectable in tests (Req 10 AC 1; tests drive the model with no
/// Core Data and no simulator).
///
/// **Invariants** enforced by `StudySessionViewModel` and asserted in
/// `StudySessionViewModelTests`:
/// 1. `phase == .emptyDeck ⟺ cards.isEmpty`.
/// 2. `phase == .completed ⟹ grades.count == cards.count`.
/// 3. `phase ∈ {.frontRevealed, .backRevealed} ⟹ 0 <= position < cards.count`.
/// 4. `grades.keys ⊆ Set(cards.map { $0.id })` — no grade for a card
///    not in the session's snapshot.
/// 5. Once `phase == .completed`, the public API does not transition
///    back to any other phase (only `returnHome()` tears the session
///    down entirely).
struct StudySession: Equatable {

    /// The source Deck's id. The session does not fetch anything by
    /// `deckId` after construction; this field is retained so the
    /// completion and exit paths can describe the source (e.g.,
    /// "You finished {deckName}") and so tests are self-describing.
    let deckId: UUID

    /// The ordered snapshot taken at session start (Req 1 AC 8,
    /// Req 9 AC 1, Req 9 AC 3). `let`, so the compiler prevents any
    /// accidental mid-session mutation. If the source Deck changes
    /// during the session, the session does not care.
    let cards: [CardSnapshot]

    /// Zero-based index of the currently displayed Card in `cards`.
    /// Valid range is `0..<cards.count` while `phase` is
    /// `.frontRevealed` or `.backRevealed`; irrelevant in `.emptyDeck`
    /// and `.completed`.
    var position: Int

    /// The single discriminator driving the view (Req 9 AC 1).
    var phase: Phase

    /// Per-card self-grade the user has assigned so far, keyed by
    /// `CardSnapshot.id` (Req 9 AC 1, Req 10 AC 3.7). An entry is
    /// written exactly when the user selects a grade for a card; no
    /// entry is ever overwritten (backward navigation is disallowed —
    /// Req 5 AC 4). The dictionary exists so a future P1 summary
    /// screen, or an in-session debug view, can see what was graded.
    var grades: [UUID: SelfGrade]

    /// Lifecycle phase of a `StudySession`. The state machine's arrows
    /// are documented in the design's state-transition table.
    enum Phase: Equatable {

        /// Current card's back is hidden. The reveal affordance is
        /// visible; grade buttons are not.
        case frontRevealed

        /// Current card's back is visible. Grade buttons are active;
        /// the reveal affordance is hidden (Req 3 AC 4).
        case backRevealed

        /// Every card in `cards` has been graded. The completion view
        /// is presented (Req 6 AC 1).
        case completed

        /// The source Deck had zero cards at session start. No card is
        /// displayed; the view surfaces an empty-state message
        /// (Req 1 AC 9, Req 1 AC 10).
        case emptyDeck
    }
}

/// Read-only projection of the current card's display data. Computed
/// by `StudySessionViewModel` from `StudySession` on demand and
/// published to the view. `nil` in the `.emptyDeck` and `.completed`
/// phases, where no card is displayed.
///
/// This is the study-side analogue of `CardRowItem` in card-management:
/// it keeps the view layer thin by pre-computing the exact fields the
/// view needs, so the view does not reach into `CardSnapshot` or
/// compute "\(position + 1) of \(total)" on its own.
struct CurrentCardView: Equatable {

    /// The current card's front text. Always rendered when the view
    /// has a `CurrentCardView` to display (Req 2 AC 1, Req 3 AC 2).
    let frontText: String

    /// The current card's back text. Always present on the projection;
    /// the view chooses whether to render it based on `phase`
    /// (Req 2 AC 2 hides it in `.frontRevealed`; Req 3 AC 2 shows it
    /// in `.backRevealed`).
    let backText: String

    /// Zero-based index of the current card. The view renders
    /// "\(position + 1) of \(total)" as the progress indicator
    /// (Req 2 AC 5).
    let position: Int

    /// Total number of cards in the session's ordered Card sequence.
    let total: Int

    /// Current phase; lets the view decide whether to show the reveal
    /// affordance, the back text, and the grade buttons from a single
    /// piece of state.
    let phase: StudySession.Phase
}
