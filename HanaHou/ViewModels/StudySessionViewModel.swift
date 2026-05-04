//
//  StudySessionViewModel.swift
//  HanaHou
//
//  Feature: study-mode
//

import Foundation
import Combine

/// The Req 9 "Study_Manager" — coordinates a `StudySession`'s lifecycle
/// (start, flip, grade, advance, complete, exit, return home) and
/// publishes state to the study view.
///
/// **Shape (design §Components and Interfaces).**
/// - Depends only on the `CardStore` and `CardOrderingStrategy`
///   **protocols** (Req 9 AC 4, 9 AC 5) — never on a concrete store or
///   strategy. This is the testability seam that lets
///   `StudySessionViewModelTests` drive the view model with
///   `InMemoryCardStore` and no Core Data stack (Req 10 AC 1).
/// - **Fetches + orders at construction time**; after that the view
///   model never touches the store. The session's ordered card
///   sequence is an immutable snapshot (`StudySession.cards` is a
///   `let`) taken at session start (Req 1 AC 8).
/// - Does **not** subscribe to `CardStore.changes`. If the source
///   Deck changes during the session, the session does not care
///   (Req 1 AC 8).
/// - Intent methods (`flip`, `grade`, `exit`, `returnHome`) are pure
///   state transitions. The state-transition table in the design doc
///   enumerates every (phase × intent) pair; tests pin each cell.
///
/// **Error handling (design §Error Handling).** The only thing that
/// can fail is `CardStore.fetchInDeck(deckId:)` at construction time.
/// On failure the view model publishes the error via `loadError` and
/// forces `phase = .emptyDeck` so the view has a safe render; the
/// view shows an alert whose OK action pops back to the Card list.
///
/// **No persistence (Req 4 AC 5, Req 7 AC 4, D039).** Recorded grades
/// live only in `session.grades`. Exit or completion discards them.
/// When P1 introduces `StudyEvent` persistence, writing a grade to a
/// new `StudyEventStore` will be an additive hook on `grade(_:)` —
/// the state machine here will not change.
@MainActor
final class StudySessionViewModel: ObservableObject {

    // MARK: - Published state

    /// Current session state. The view renders `.phase`-dependent
    /// surfaces (Req 9 AC 1).
    @Published private(set) var session: StudySession

    /// Projection of the current card's display data. `nil` in the
    /// `.emptyDeck` and `.completed` phases.
    @Published private(set) var currentCard: CurrentCardView?

    /// Error from the initial fetch. Surfaced as an alert by
    /// `StudyView`; cleared by the view when the alert's OK action
    /// fires.
    @Published var loadError: Error?

    // MARK: - Dependencies (protocols only — Req 9 AC 4, 9 AC 5)

    private let store: CardStore
    private let strategy: CardOrderingStrategy

    // MARK: - Init (fetches + orders at construction time)

    /// Loads every Card associated with `deckId` from `store`, applies
    /// `strategy.order(_:)` to the result, and establishes the
    /// session's initial phase (Req 1 AC 2, 1 AC 3, 1 AC 6, 1 AC 9,
    /// Req 9 AC 3). Synchronous — matches how `CardListViewModel`
    /// fetches in its `init`.
    ///
    /// On fetch failure, the view model still constructs a valid
    /// session (phase `.emptyDeck`, no cards) so the view has
    /// something safe to render, and sets `loadError` so the view can
    /// surface an alert.
    init(
        deckId: UUID,
        store: CardStore,
        strategy: CardOrderingStrategy
    ) {
        self.store = store
        self.strategy = strategy

        let orderedCards: [CardSnapshot]
        let initialLoadError: Error?
        do {
            let fetched = try store.fetchInDeck(deckId: deckId)
            orderedCards = strategy.order(fetched)
            initialLoadError = nil
        } catch {
            orderedCards = []
            initialLoadError = error
        }

        let initialPhase: StudySession.Phase = orderedCards.isEmpty
            ? .emptyDeck
            : .frontRevealed

        self.session = StudySession(
            deckId: deckId,
            cards: orderedCards,
            position: 0,
            phase: initialPhase,
            grades: [:]
        )
        self.loadError = initialLoadError
        self.currentCard = Self.projection(from: session)
    }

    // MARK: - Deinit
    //
    // An explicit `nonisolated deinit` sidesteps the compiler-synthesized
    // isolated-deinit path for `@MainActor` classes under Swift 6. Without
    // this, the task-executor's deinit hop (swift_task_deinitOnExecutorImpl)
    // can trip a libmalloc "pointer being freed was not allocated" trap
    // when an `@MainActor` view model is deallocated synchronously on the
    // main thread (e.g., at the end of a test method on an
    // `@MainActor XCTestCase`). The view model holds no resources that
    // need main-actor cleanup — `@Published` teardown is safe off-actor —
    // so an empty `nonisolated deinit` is both correct and safe.

    nonisolated deinit {}

    // MARK: - Intents

    /// Transitions `.frontRevealed` → `.backRevealed` for the current
    /// card (Req 3 AC 1). No-op in every other phase (Req 3 AC 5,
    /// design §State transitions — explicit table).
    func flip() {
        guard session.phase == .frontRevealed else {
            return
        }
        session.phase = .backRevealed
        refreshCurrentCard()
    }

    /// Records `grade` against the current card's id and advances
    /// (Req 4 AC 3, 4 AC 4, 5 AC 1, 5 AC 2). No-op in every phase
    /// except `.backRevealed` (design §State transitions — explicit
    /// table): grading is gated on the back reveal.
    func grade(_ grade: SelfGrade) {
        guard session.phase == .backRevealed else {
            return
        }
        guard session.position >= 0, session.position < session.cards.count else {
            // Invariant (3): in .backRevealed, position must be in range.
            // If this ever trips, something has corrupted the state —
            // fail safe by refusing the intent rather than crashing.
            return
        }

        let currentId = session.cards[session.position].id
        session.grades[currentId] = grade

        let lastIndex = session.cards.count - 1
        if session.position < lastIndex {
            session.position += 1
            session.phase = .frontRevealed
        } else {
            session.phase = .completed
        }
        refreshCurrentCard()
    }

    /// Discards all session state (Req 7 AC 2). The caller pops the
    /// navigation stack one level back to the Card list (Req 7 AC 3).
    /// No grade is persisted (Req 7 AC 4, Req 4 AC 5).
    func exit() {
        clearSessionState()
    }

    /// Discards all session state after the completion view
    /// (Req 6 AC 6). The caller pops the navigation stack to the Deck
    /// list root (Req 6 AC 5).
    func returnHome() {
        clearSessionState()
    }

    // MARK: - Private helpers

    private func clearSessionState() {
        session = StudySession(
            deckId: session.deckId,
            cards: [],
            position: 0,
            phase: .emptyDeck,
            grades: [:]
        )
        refreshCurrentCard()
    }

    private func refreshCurrentCard() {
        currentCard = Self.projection(from: session)
    }

    /// Computes the `CurrentCardView` projection from a `StudySession`.
    /// Returns `nil` in the `.emptyDeck` and `.completed` phases, where
    /// no card is displayed.
    private static func projection(from session: StudySession) -> CurrentCardView? {
        switch session.phase {
        case .emptyDeck, .completed:
            return nil
        case .frontRevealed, .backRevealed:
            guard session.cards.indices.contains(session.position) else {
                return nil
            }
            let card = session.cards[session.position]
            return CurrentCardView(
                frontText: card.frontText,
                backText: card.backText,
                position: session.position,
                total: session.cards.count,
                phase: session.phase
            )
        }
    }
}
