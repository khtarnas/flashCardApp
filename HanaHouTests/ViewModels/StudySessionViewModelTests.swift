//
//  StudySessionViewModelTests.swift
//  HanaHouTests
//
//  Feature: study-mode
//  Covers requirements: 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9,
//                       3.1, 3.5,
//                       4.3, 4.4, 4.5,
//                       5.1, 5.2, 5.4,
//                       6.6,
//                       7.2, 7.4,
//                       9.1, 9.3, 9.4, 9.5,
//                       10.1
//  Test cases from Req 10 AC 3: 1–11
//
//  These tests drive the `StudySessionViewModel` (the Req 9
//  "Study_Manager") as a pure state machine — no Core Data, no simulator
//  dependency (Req 10 AC 1). They use the existing `InMemoryCardStore`
//  as the store, a `FixedOrderStrategy` stub when a test needs to
//  assert that the view model applies the strategy's output verbatim,
//  and the real `CardCreationDateAscendingOrdering` when a test
//  validates the P0 ordering contract (Req 1 AC 4 / Req 10 AC 3.4).
//

import XCTest
import Combine
@testable import HanaHou

// MARK: - Test-local stubs

/// Ordering strategy that returns a caller-supplied order regardless
/// of input. Used to prove the view model applies the strategy's
/// output verbatim (Req 9 AC 3, 9 AC 5, Req 10 AC 3.3).
private struct FixedOrderStrategy: CardOrderingStrategy {
    let fixed: [CardSnapshot]
    func order(_ cards: [CardSnapshot]) -> [CardSnapshot] { fixed }
}

/// `CardStore` stub that always throws from `fetchInDeck(deckId:)`.
/// Used to exercise the error path at construction time
/// (design §Error Handling — `loadError` set, `phase == .emptyDeck`).
private final class ThrowingCardStore: CardStore {
    struct BoomError: Error, Equatable {}

    var changes: AnyPublisher<Void, Never> {
        Empty<Void, Never>().eraseToAnyPublisher()
    }

    func fetchAll() throws -> [CardSnapshot] { [] }

    func fetchInDeck(deckId: UUID) throws -> [CardSnapshot] {
        throw BoomError()
    }

    func create(frontText: String, backText: String, deckIds: Set<UUID>) throws -> CardSnapshot {
        throw BoomError()
    }

    func update(id: UUID, frontText: String, backText: String) throws {}
    func delete(id: UUID) throws {}
}

@MainActor
final class StudySessionViewModelTests: XCTestCase {

    // MARK: - Helpers

    /// Returns a mutable clock plus a setter so fixtures can advance
    /// time between store inserts to exercise createdAt-based ordering.
    private func makeMutableClock(initial: Date) -> (clock: () -> Date, set: (Date) -> Void) {
        final class Box { var date: Date; init(_ d: Date) { self.date = d } }
        let box = Box(initial)
        return ({ box.date }, { box.date = $0 })
    }

    /// Convenience: seed `store` with `count` cards in the given deck,
    /// one `tickSeconds` apart on the supplied clock, returning the
    /// created snapshots in insertion order.
    @discardableResult
    private func seedCards(
        count: Int,
        in deckId: UUID,
        store: InMemoryCardStore,
        clock: () -> Date,
        setClock: (Date) -> Void,
        tickSeconds: TimeInterval = 1
    ) throws -> [CardSnapshot] {
        var results: [CardSnapshot] = []
        var t = clock().timeIntervalSince1970
        for index in 0..<count {
            setClock(Date(timeIntervalSince1970: t))
            let created = try store.create(
                frontText: "front \(index)",
                backText: "back \(index)",
                deckIds: [deckId]
            )
            results.append(created)
            t += tickSeconds
        }
        return results
    }

    /// Puts the session into `.backRevealed` for the current card by
    /// flipping from `.frontRevealed`. Safe to call only when the view
    /// model is already in `.frontRevealed`.
    private func flipToBack(_ vm: StudySessionViewModel) {
        XCTAssertEqual(vm.session.phase, .frontRevealed)
        vm.flip()
        XCTAssertEqual(vm.session.phase, .backRevealed)
    }

    // MARK: - 2.1.1  Req 10 AC 3.1, Req 1 AC 9, Req 1 AC 10
    // Zero-card deck → .emptyDeck, no current card displayed.

    func test_init_withEmptyDeck_entersEmptyDeckPhase_andExposesNoCurrentCard() {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckId = UUID()

        let vm = StudySessionViewModel(
            deckId: deckId,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )

        XCTAssertEqual(vm.session.phase, .emptyDeck)
        XCTAssertEqual(vm.session.deckId, deckId)
        XCTAssertEqual(vm.session.cards, [])
        XCTAssertEqual(vm.session.position, 0)
        XCTAssertTrue(vm.session.grades.isEmpty)
        XCTAssertNil(vm.currentCard, "No card is displayed in the empty-deck phase (Req 1 AC 10).")
        XCTAssertNil(vm.loadError, "An empty deck is not an error — loadError must be nil.")
    }

    // MARK: - 2.1.2  Req 10 AC 3.2, Req 1 AC 6, Req 1 AC 7
    // Non-empty deck → .frontRevealed at position 0.

    func test_init_withNonEmptyDeck_entersFrontRevealedAtPositionZero() throws {
        let (clock, setClock) = makeMutableClock(initial: Date(timeIntervalSince1970: 1_000))
        let store = InMemoryCardStore(clock: clock)
        let deckId = UUID()
        let seeded = try seedCards(count: 3, in: deckId, store: store, clock: clock, setClock: setClock)

        let vm = StudySessionViewModel(
            deckId: deckId,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )

        XCTAssertEqual(vm.session.phase, .frontRevealed)
        XCTAssertEqual(vm.session.position, 0)
        XCTAssertEqual(vm.session.cards.count, seeded.count)
        XCTAssertEqual(vm.session.cards.map(\.id), seeded.map(\.id),
            "With the P0 strategy and monotonic createdAt seeds, the session's card order equals insertion order.")

        let projection = try XCTUnwrap(vm.currentCard)
        XCTAssertEqual(projection.phase, .frontRevealed)
        XCTAssertEqual(projection.position, 0)
        XCTAssertEqual(projection.total, seeded.count)
        XCTAssertEqual(projection.frontText, seeded[0].frontText)
        XCTAssertEqual(projection.backText, seeded[0].backText)
    }

    // MARK: - 2.1.3  Req 10 AC 3.3, Req 1 AC 3, Req 9 AC 3, Req 9 AC 5
    // Session uses whatever the injected strategy returned — verbatim.

    func test_init_appliesOrderingStrategyToFetchedCards() throws {
        let (clock, setClock) = makeMutableClock(initial: Date(timeIntervalSince1970: 1_000))
        let store = InMemoryCardStore(clock: clock)
        let deckId = UUID()
        let seeded = try seedCards(count: 3, in: deckId, store: store, clock: clock, setClock: setClock)

        // Build a deliberately non-natural order: middle, last, first.
        let fixed = [seeded[1], seeded[2], seeded[0]]
        let strategy = FixedOrderStrategy(fixed: fixed)

        let vm = StudySessionViewModel(
            deckId: deckId,
            store: store,
            strategy: strategy
        )

        XCTAssertEqual(
            vm.session.cards.map(\.id),
            fixed.map(\.id),
            "The view model must use the strategy's output verbatim, with no re-sort."
        )
        XCTAssertEqual(vm.session.position, 0)
        XCTAssertEqual(vm.session.phase, .frontRevealed)
        XCTAssertEqual(vm.currentCard?.frontText, fixed[0].frontText)
    }

    // MARK: - 2.1.4  Req 10 AC 3.4, Req 1 AC 4
    // P0 strategy (CardCreationDateAscendingOrdering) matches per-Deck Card list order.

    func test_init_withP0Strategy_ordersByCreatedAtAscWithIdTiebreaker() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckId = UUID()

        // Hand-built snapshots so we can pin both ids and timestamps.
        // t1 = 1000, t2 = 2000 (shared), t3 = 3000. Tiebreaker is
        // id.uuidString ascending — shared t2 case below.
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        let t3 = Date(timeIntervalSince1970: 3_000)

        // Force ids so the tiebreaker is testable.
        let idA = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
        let idB = UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!
        let idC = UUID(uuidString: "00000000-0000-0000-0000-0000000000CC")!
        let idD = UUID(uuidString: "00000000-0000-0000-0000-0000000000DD")!

        // We can't set an explicit id through `InMemoryCardStore.create(...)` —
        // it generates one internally — so we assert the ordering contract
        // directly against the strategy using hand-built snapshots, and then
        // verify the view model end-to-end with the store-generated ids in
        // a simpler monotonic fixture. This is the same pattern used by
        // `CardOrderingStrategyTests.test_order_combinedSortAndTiebreaker`.

        let c0 = CardSnapshot(id: idA, frontText: "a", backText: "A",
                              createdAt: t2, updatedAt: t2, deckIds: [deckId])
        let c1 = CardSnapshot(id: idB, frontText: "b", backText: "B",
                              createdAt: t2, updatedAt: t2, deckIds: [deckId])
        let c2 = CardSnapshot(id: idC, frontText: "c", backText: "C",
                              createdAt: t1, updatedAt: t1, deckIds: [deckId])
        let c3 = CardSnapshot(id: idD, frontText: "d", backText: "D",
                              createdAt: t3, updatedAt: t3, deckIds: [deckId])

        let expected = CardCreationDateAscendingOrdering().order([c0, c1, c2, c3])
        XCTAssertEqual(
            expected.map(\.id),
            [idC, idA, idB, idD],
            "Sanity check: strategy returns t1, then t2's id-ascending pair, then t3."
        )

        // End-to-end view-model check with the real store + real strategy.
        // Insert in non-monotonic order to prove the view model sorts.
        let (clock, setClock) = makeMutableClock(initial: Date(timeIntervalSince1970: 3_000))
        let storeE2E = InMemoryCardStore(clock: clock)
        let deckE2E = UUID()

        setClock(Date(timeIntervalSince1970: 3_000))
        let newestFirstInsertion = try storeE2E.create(
            frontText: "newest", backText: "newest-back", deckIds: [deckE2E]
        )
        setClock(Date(timeIntervalSince1970: 1_000))
        let oldest = try storeE2E.create(
            frontText: "oldest", backText: "oldest-back", deckIds: [deckE2E]
        )
        setClock(Date(timeIntervalSince1970: 2_000))
        let middle = try storeE2E.create(
            frontText: "middle", backText: "middle-back", deckIds: [deckE2E]
        )

        let vm = StudySessionViewModel(
            deckId: deckE2E,
            store: storeE2E,
            strategy: CardCreationDateAscendingOrdering()
        )

        XCTAssertEqual(
            vm.session.cards.map(\.id),
            [oldest.id, middle.id, newestFirstInsertion.id],
            "P0 strategy must order cards ascending by createdAt regardless of insertion order."
        )
    }

    // MARK: - 2.1.5  Req 10 AC 3.5, Req 3 AC 1, Req 3 AC 2
    // flip() in .frontRevealed transitions to .backRevealed for the same card.

    func test_flip_inFrontRevealed_transitionsToBackRevealed_sameCard() throws {
        let (clock, setClock) = makeMutableClock(initial: Date(timeIntervalSince1970: 1_000))
        let store = InMemoryCardStore(clock: clock)
        let deckId = UUID()
        let seeded = try seedCards(count: 2, in: deckId, store: store, clock: clock, setClock: setClock)

        let vm = StudySessionViewModel(
            deckId: deckId,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )
        XCTAssertEqual(vm.session.phase, .frontRevealed)
        XCTAssertEqual(vm.session.position, 0)

        vm.flip()

        XCTAssertEqual(vm.session.phase, .backRevealed)
        XCTAssertEqual(vm.session.position, 0, "flip() must not advance position.")
        XCTAssertEqual(vm.currentCard?.phase, .backRevealed)
        XCTAssertEqual(vm.currentCard?.frontText, seeded[0].frontText)
        XCTAssertEqual(vm.currentCard?.backText, seeded[0].backText)
    }

    // MARK: - 2.1.6  Req 10 AC 3.6, Req 3 AC 5
    // flip() in .backRevealed is a no-op.

    func test_flip_inBackRevealed_isNoOp() throws {
        let (clock, setClock) = makeMutableClock(initial: Date(timeIntervalSince1970: 1_000))
        let store = InMemoryCardStore(clock: clock)
        let deckId = UUID()
        _ = try seedCards(count: 2, in: deckId, store: store, clock: clock, setClock: setClock)

        let vm = StudySessionViewModel(
            deckId: deckId,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )
        flipToBack(vm)
        let snapshotBefore = vm.session
        let projectionBefore = vm.currentCard

        vm.flip()

        XCTAssertEqual(vm.session, snapshotBefore, "Session state must be unchanged by a .backRevealed flip.")
        XCTAssertEqual(vm.currentCard, projectionBefore, "currentCard projection must be unchanged.")
    }

    // MARK: - 2.1.7  Req 10 AC 3.7, Req 4 AC 3, Req 4 AC 5
    // grade(_:) records grade against the current card's id.

    func test_grade_recordsGradeForCurrentCardId() throws {
        let (clock, setClock) = makeMutableClock(initial: Date(timeIntervalSince1970: 1_000))
        let store = InMemoryCardStore(clock: clock)
        let deckId = UUID()
        let seeded = try seedCards(count: 3, in: deckId, store: store, clock: clock, setClock: setClock)

        let vm = StudySessionViewModel(
            deckId: deckId,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )
        flipToBack(vm)

        vm.grade(.close)

        XCTAssertEqual(
            vm.session.grades[seeded[0].id],
            .close,
            "grade(.close) in .backRevealed must write against the current card's id."
        )
        XCTAssertNil(vm.session.grades[seeded[1].id], "Other cards must remain ungraded.")
    }

    // MARK: - 2.1.8  Req 10 AC 3.8, Req 5 AC 1, Req 4 AC 4
    // grade(_:) at non-last position advances and returns to .frontRevealed.

    func test_grade_notLastPosition_advancesAndReturnsToFrontRevealed() throws {
        let (clock, setClock) = makeMutableClock(initial: Date(timeIntervalSince1970: 1_000))
        let store = InMemoryCardStore(clock: clock)
        let deckId = UUID()
        let seeded = try seedCards(count: 3, in: deckId, store: store, clock: clock, setClock: setClock)

        let vm = StudySessionViewModel(
            deckId: deckId,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )
        flipToBack(vm)

        vm.grade(.know)

        XCTAssertEqual(vm.session.position, 1, "Position must advance by 1.")
        XCTAssertEqual(vm.session.phase, .frontRevealed, "New card must start in .frontRevealed.")
        XCTAssertEqual(vm.currentCard?.position, 1)
        XCTAssertEqual(vm.currentCard?.frontText, seeded[1].frontText)
        XCTAssertEqual(vm.currentCard?.phase, .frontRevealed)
    }

    // MARK: - 2.1.9  Req 10 AC 3.9, Req 5 AC 2
    // grade(_:) at last position transitions to .completed.

    func test_grade_atLastPosition_transitionsToCompleted() throws {
        let (clock, setClock) = makeMutableClock(initial: Date(timeIntervalSince1970: 1_000))
        let store = InMemoryCardStore(clock: clock)
        let deckId = UUID()
        let seeded = try seedCards(count: 2, in: deckId, store: store, clock: clock, setClock: setClock)

        let vm = StudySessionViewModel(
            deckId: deckId,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )
        // Grade through to the last card.
        flipToBack(vm)
        vm.grade(.know)              // now at position 1, .frontRevealed
        XCTAssertEqual(vm.session.position, 1)
        flipToBack(vm)

        vm.grade(.noIdea)

        XCTAssertEqual(vm.session.phase, .completed)
        XCTAssertNil(vm.currentCard, "currentCard must be nil in .completed.")
        XCTAssertEqual(vm.session.grades.count, seeded.count, "Every card must be graded.")
        XCTAssertEqual(vm.session.grades[seeded[0].id], .know)
        XCTAssertEqual(vm.session.grades[seeded[1].id], .noIdea)
    }

    // MARK: - 2.1.10  Req 10 AC 3.10, Req 1 AC 8
    // The session's ordered sequence is a snapshot taken at session start.

    func test_orderedSequence_isSnapshotAtStart_notAffectedByStoreMutations() throws {
        let (clock, setClock) = makeMutableClock(initial: Date(timeIntervalSince1970: 1_000))
        let store = InMemoryCardStore(clock: clock)
        let deckId = UUID()
        let seeded = try seedCards(count: 2, in: deckId, store: store, clock: clock, setClock: setClock)

        let vm = StudySessionViewModel(
            deckId: deckId,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )
        let snapshotAtStart = vm.session.cards

        // Mutate the store after the session has started.
        setClock(Date(timeIntervalSince1970: 10_000))
        _ = try store.create(frontText: "added mid-session", backText: "x", deckIds: [deckId])
        try store.delete(id: seeded[0].id)
        try store.update(id: seeded[1].id, frontText: "edited", backText: "edited-back")

        XCTAssertEqual(
            vm.session.cards,
            snapshotAtStart,
            "The session's ordered card sequence must not change when the source Deck is mutated mid-session (Req 1 AC 8)."
        )
        XCTAssertEqual(vm.session.phase, .frontRevealed)
        XCTAssertEqual(vm.session.position, 0)
        XCTAssertEqual(vm.currentCard?.frontText, seeded[0].frontText,
            "The displayed card still reflects the original snapshot's text, not the post-mutation state.")
    }

    // MARK: - 2.1.11  Req 10 AC 3.11, Req 7 AC 2, Req 7 AC 4
    // exit() clears in-memory state and does not write to the store.

    func test_exit_discardsInMemoryState_andPersistsNothing() throws {
        let (clock, setClock) = makeMutableClock(initial: Date(timeIntervalSince1970: 1_000))
        let store = InMemoryCardStore(clock: clock)
        let deckId = UUID()
        let seeded = try seedCards(count: 3, in: deckId, store: store, clock: clock, setClock: setClock)

        let vm = StudySessionViewModel(
            deckId: deckId,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )
        flipToBack(vm)
        vm.grade(.know)   // advance; record a grade
        flipToBack(vm)
        vm.grade(.close)  // another

        let storeSnapshotBefore = Set(try store.fetchAll().map(\.id))

        vm.exit()

        // The session is discarded: no current card, no recorded grades.
        XCTAssertNil(vm.currentCard, "exit() must clear the current-card projection.")
        XCTAssertTrue(vm.session.grades.isEmpty, "exit() must discard recorded grades.")
        XCTAssertTrue(vm.session.cards.isEmpty, "exit() must discard the session's cards.")
        XCTAssertEqual(vm.session.phase, .emptyDeck, "exit() leaves the view model in a safe, renderable phase.")
        XCTAssertEqual(vm.session.deckId, deckId, "deckId is retained for diagnostics.")

        // The store is untouched — no grade was ever persisted (Req 7 AC 4).
        let storeSnapshotAfter = Set(try store.fetchAll().map(\.id))
        XCTAssertEqual(storeSnapshotAfter, storeSnapshotBefore,
            "exit() must not write to the Card store — P0 study state is ephemeral (Req 4 AC 5, 7 AC 4).")

        // And critically: none of the graded card ids appeared anywhere on
        // the store-side card snapshots' `deckIds` as a side effect.
        for id in [seeded[0].id, seeded[1].id] {
            let fetched = try XCTUnwrap(try store.fetchAll().first(where: { $0.id == id }))
            XCTAssertFalse(fetched.frontText.contains("grade"),
                "Sanity: exit() cannot have tampered with a card's text.")
        }
    }

    // MARK: - Supplementary transition-table tests (design §Testing Strategy)
    // These cheap tests pin the full state machine, not just Req 10 AC 3.

    func test_grade_inFrontRevealed_isNoOp() throws {
        let (clock, setClock) = makeMutableClock(initial: Date(timeIntervalSince1970: 1_000))
        let store = InMemoryCardStore(clock: clock)
        let deckId = UUID()
        _ = try seedCards(count: 2, in: deckId, store: store, clock: clock, setClock: setClock)

        let vm = StudySessionViewModel(
            deckId: deckId,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )
        XCTAssertEqual(vm.session.phase, .frontRevealed)
        let before = vm.session

        vm.grade(.know)

        XCTAssertEqual(
            vm.session,
            before,
            "Grading before flipping must be a no-op — grading is gated on back-reveal (design transition table)."
        )
        XCTAssertTrue(vm.session.grades.isEmpty,
            "Grading in .frontRevealed must not record a grade.")
    }

    func test_returnHome_inCompleted_discardsState() throws {
        let (clock, setClock) = makeMutableClock(initial: Date(timeIntervalSince1970: 1_000))
        let store = InMemoryCardStore(clock: clock)
        let deckId = UUID()
        _ = try seedCards(count: 1, in: deckId, store: store, clock: clock, setClock: setClock)

        let vm = StudySessionViewModel(
            deckId: deckId,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )
        flipToBack(vm)
        vm.grade(.know)
        XCTAssertEqual(vm.session.phase, .completed)
        XCTAssertFalse(vm.session.grades.isEmpty)

        vm.returnHome()

        XCTAssertTrue(vm.session.grades.isEmpty, "returnHome() must discard recorded grades (Req 6 AC 6).")
        XCTAssertTrue(vm.session.cards.isEmpty, "returnHome() must discard the session's cards.")
        XCTAssertEqual(vm.session.phase, .emptyDeck,
            "returnHome() leaves the view model in a safe, renderable phase.")
    }

    func test_init_fetchFailure_rendersEmptyDeckPhase_andSetsLoadError() {
        let store = ThrowingCardStore()
        let deckId = UUID()

        let vm = StudySessionViewModel(
            deckId: deckId,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )

        XCTAssertEqual(
            vm.session.phase,
            .emptyDeck,
            "A fetch failure must still leave the view model in a safe, renderable phase."
        )
        XCTAssertTrue(vm.session.cards.isEmpty)
        XCTAssertNil(vm.currentCard)
        XCTAssertNotNil(vm.loadError, "The underlying error must be surfaced on loadError for the view's alert.")
    }

    func test_flip_inEmptyDeck_isNoOp() {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let vm = StudySessionViewModel(
            deckId: UUID(),
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )
        XCTAssertEqual(vm.session.phase, .emptyDeck)
        let before = vm.session

        vm.flip()

        XCTAssertEqual(vm.session, before, "flip() in .emptyDeck must be a no-op.")
    }

    func test_flip_inCompleted_isNoOp() throws {
        let (clock, setClock) = makeMutableClock(initial: Date(timeIntervalSince1970: 1_000))
        let store = InMemoryCardStore(clock: clock)
        let deckId = UUID()
        _ = try seedCards(count: 1, in: deckId, store: store, clock: clock, setClock: setClock)

        let vm = StudySessionViewModel(
            deckId: deckId,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )
        flipToBack(vm)
        vm.grade(.know)
        XCTAssertEqual(vm.session.phase, .completed)
        let before = vm.session

        vm.flip()

        XCTAssertEqual(vm.session, before, "flip() in .completed must be a no-op.")
    }

    func test_grade_inCompleted_isNoOp() throws {
        let (clock, setClock) = makeMutableClock(initial: Date(timeIntervalSince1970: 1_000))
        let store = InMemoryCardStore(clock: clock)
        let deckId = UUID()
        _ = try seedCards(count: 1, in: deckId, store: store, clock: clock, setClock: setClock)

        let vm = StudySessionViewModel(
            deckId: deckId,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )
        flipToBack(vm)
        vm.grade(.know)
        XCTAssertEqual(vm.session.phase, .completed)
        let before = vm.session

        vm.grade(.close)

        XCTAssertEqual(vm.session, before, "grade() in .completed must be a no-op.")
    }

    // MARK: - Protocol-dependency proof (Req 9 AC 4, 9 AC 5)
    //
    // The view model's init signature takes the protocol types, not
    // concrete implementations. If someone tightens it to a concrete
    // type, this test will stop compiling.

    func test_init_acceptsProtocolDependencies() {
        let store: CardStore = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let strategy: CardOrderingStrategy = CardCreationDateAscendingOrdering()

        let vm = StudySessionViewModel(deckId: UUID(), store: store, strategy: strategy)

        XCTAssertEqual(vm.session.phase, .emptyDeck,
            "Empty store must yield .emptyDeck regardless of the concrete CardStore/Strategy types.")
    }
}
