//
//  CardListViewModelTests.swift
//  HanaHouTests
//
//  Feature: card-management
//  Covers behaviors: C3, C4, C5, C8, C11, C12
//  Validates requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 4.2, 4.3, 7.4
//

import XCTest
import Combine
@testable import HanaHou

/// Reverse-ordering stub strategy injected alongside `CardCreationDateAscendingOrdering`
/// so tests can assert the view model is strategy-independent — it must use whatever
/// strategy it's handed at init time (matches the deck-side `ReverseOrderingStub`
/// pattern in `DeckListViewModelTests`).
private struct ReverseCardOrderingStub: CardOrderingStrategy {
    func order(_ cards: [CardSnapshot]) -> [CardSnapshot] { cards.reversed() }
}

@MainActor
final class CardListViewModelTests: XCTestCase {

    // MARK: - Helpers

    /// Returns a mutable clock closure plus a setter, so tests can advance time
    /// between creations to exercise `createdAt`-based ordering (C8).
    private func makeMutableClock(initial: Date) -> (clock: () -> Date, set: (Date) -> Void) {
        final class Box { var date: Date; init(_ d: Date) { self.date = d } }
        let box = Box(initial)
        return ({ box.date }, { box.date = $0 })
    }

    /// Advances the runloop briefly so Combine emissions have time to propagate
    /// through the view model's `store.changes` subscription.
    private func waitBriefly(_ timeout: TimeInterval = 0.05) {
        let exp = expectation(description: "brief wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// Extracts row ids from a `[CardRowItem]` for order-sensitive assertions.
    private func rowIds(_ items: [CardRowItem]) -> [UUID] {
        items.map(\.id)
    }

    // MARK: - C12: Empty state
    // Requirements: 2.5

    func test_items_isEmpty_whenStoreIsEmpty() {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckId = UUID()

        let vm = CardListViewModel(
            deckId: deckId,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )

        XCTAssertTrue(vm.items.isEmpty)
    }

    func test_items_isEmpty_whenStoreHasCardsInOtherDecks() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckX = UUID()
        let deckY = UUID()

        _ = try store.create(frontText: "front", backText: "back", deckIds: [deckX])
        _ = try store.create(frontText: "front 2", backText: "back 2", deckIds: [deckX])

        let vm = CardListViewModel(
            deckId: deckY,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )

        XCTAssertTrue(
            vm.items.isEmpty,
            "Cards not associated with the view model's deckId must never appear in items"
        )
    }

    // MARK: - C3: Create propagates into items
    // Requirements: 2.1, 2.4

    func test_items_includesCardCreatedInThisDeck_afterCreate() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckA = UUID()

        let vm = CardListViewModel(
            deckId: deckA,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )
        XCTAssertTrue(vm.items.isEmpty)

        let created = try store.create(frontText: "front", backText: "back", deckIds: [deckA])
        waitBriefly()

        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(vm.items.first?.id, created.id)
    }

    func test_items_excludesCardCreatedInOtherDeck() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckA = UUID()
        let deckB = UUID()

        let vm = CardListViewModel(
            deckId: deckA,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )

        _ = try store.create(frontText: "front", backText: "back", deckIds: [deckB])
        waitBriefly()

        XCTAssertTrue(
            vm.items.isEmpty,
            "A card created in another deck must not appear in this view model's items"
        )
    }

    // MARK: - C4: Update propagates
    // Requirements: 2.4

    func test_items_reflectsEditedCardText() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckA = UUID()

        let vm = CardListViewModel(
            deckId: deckA,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )

        let created = try store.create(
            frontText: "old front",
            backText: "old back",
            deckIds: [deckA]
        )
        waitBriefly()

        try store.update(id: created.id, frontText: "new front", backText: "new back")
        waitBriefly()

        XCTAssertEqual(vm.items.count, 1)
        let row = try XCTUnwrap(vm.items.first)
        XCTAssertEqual(row.id, created.id)
        XCTAssertEqual(row.frontText, "new front")
        XCTAssertEqual(row.backText, "new back")
    }

    // MARK: - C5: Delete propagates
    // Requirements: 2.4, 4.2, 4.3

    func test_items_removesDeletedCard() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckA = UUID()

        let vm = CardListViewModel(
            deckId: deckA,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )

        let first = try store.create(frontText: "one", backText: "1", deckIds: [deckA])
        let second = try store.create(frontText: "two", backText: "2", deckIds: [deckA])
        waitBriefly()
        XCTAssertEqual(Set(rowIds(vm.items)), Set([first.id, second.id]))

        try store.delete(id: first.id)
        waitBriefly()

        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(vm.items.first?.id, second.id)
    }

    func test_items_reflectsCardDetachedFromDeck() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckA = UUID()

        let vm = CardListViewModel(
            deckId: deckA,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )

        _ = try store.create(frontText: "front", backText: "back", deckIds: [deckA])
        waitBriefly()
        XCTAssertEqual(vm.items.count, 1)

        // Simulate the shared-context deck-deletion path: the card becomes an
        // orphan and must disappear from the per-deck list's items.
        store.simulateDeckDeleted(deckId: deckA)
        waitBriefly()

        XCTAssertTrue(
            vm.items.isEmpty,
            "A card detached from this deck (orphaned) must no longer appear in items"
        )
    }

    // MARK: - C8: Ordering is determined by the injected strategy
    // Requirements: 2.3

    func test_items_sortedByP0Strategy_createdAtAscending() throws {
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 3_000)
        let t3 = Date(timeIntervalSince1970: 2_000)
        let (clock, setClock) = makeMutableClock(initial: t1)
        let store = InMemoryCardStore(clock: clock)
        let deckA = UUID()

        // Seed order is c1, c2, c3 but timestamps are t1 < t3 < t2, so
        // createdAt-ascending order should be c1, c3, c2.
        let c1 = try store.create(frontText: "one",   backText: "1", deckIds: [deckA])
        setClock(t2)
        let c2 = try store.create(frontText: "two",   backText: "2", deckIds: [deckA])
        setClock(t3)
        let c3 = try store.create(frontText: "three", backText: "3", deckIds: [deckA])

        let vm = CardListViewModel(
            deckId: deckA,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )

        XCTAssertEqual(rowIds(vm.items), [c1.id, c3.id, c2.id])
    }

    func test_items_usesReverseStrategy() throws {
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 3_000)
        let t3 = Date(timeIntervalSince1970: 2_000)
        let (clock, setClock) = makeMutableClock(initial: t1)
        let store = InMemoryCardStore(clock: clock)
        let deckA = UUID()

        _ = try store.create(frontText: "one",   backText: "1", deckIds: [deckA])
        setClock(t2)
        _ = try store.create(frontText: "two",   backText: "2", deckIds: [deckA])
        setClock(t3)
        _ = try store.create(frontText: "three", backText: "3", deckIds: [deckA])

        let strategy = ReverseCardOrderingStub()
        let vm = CardListViewModel(
            deckId: deckA,
            store: store,
            strategy: strategy
        )

        // The reverse stub reverses whatever `fetchInDeck` returns — the
        // view model must use the injected strategy verbatim, without
        // reapplying its own ordering.
        let expectedIds = strategy.order(try store.fetchInDeck(deckId: deckA)).map(\.id)
        XCTAssertEqual(rowIds(vm.items), expectedIds)
    }

    // MARK: - C11: changes subscription drives reloads
    // Requirements: 2.4, 4.3

    func test_items_updatesAfterEveryMutation() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckA = UUID()

        let vm = CardListViewModel(
            deckId: deckA,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )
        XCTAssertTrue(vm.items.isEmpty)

        // Create
        let created = try store.create(frontText: "front", backText: "back", deckIds: [deckA])
        waitBriefly()
        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(vm.items.first?.frontText, "front")
        XCTAssertEqual(vm.items.first?.backText, "back")

        // Update
        try store.update(id: created.id, frontText: "front 2", backText: "back 2")
        waitBriefly()
        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(vm.items.first?.frontText, "front 2")
        XCTAssertEqual(vm.items.first?.backText, "back 2")

        // Delete
        try store.delete(id: created.id)
        waitBriefly()
        XCTAssertTrue(vm.items.isEmpty)
    }

    // MARK: - snapshotsById lookup
    // Per design §ViewModels / CardListViewModel — the view needs to resolve a
    // tapped `CardRowItem.id` back to the underlying `CardSnapshot` to route
    // to `.editCard(snapshot)`. Exposed to tests as `snapshot(forRowId:)`.

    func test_snapshotForRowId_returnsMatchingSnapshot() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckA = UUID()

        let vm = CardListViewModel(
            deckId: deckA,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )

        let created = try store.create(frontText: "front", backText: "back", deckIds: [deckA])
        waitBriefly()

        let resolved = vm.snapshot(forRowId: created.id)
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.id, created.id)
        XCTAssertEqual(resolved?.frontText, "front")
        XCTAssertEqual(resolved?.backText, "back")

        XCTAssertNil(
            vm.snapshot(forRowId: UUID()),
            "Looking up an unknown row id must return nil"
        )
    }

    // MARK: - delete(id:) dispatch
    // Requirements: 4.2, 4.3

    func test_delete_dispatchesToStore() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckA = UUID()

        let vm = CardListViewModel(
            deckId: deckA,
            store: store,
            strategy: CardCreationDateAscendingOrdering()
        )

        let created = try store.create(frontText: "front", backText: "back", deckIds: [deckA])
        waitBriefly()
        XCTAssertEqual(vm.items.count, 1)

        try vm.delete(id: created.id)
        waitBriefly()

        let all = try store.fetchAll()
        XCTAssertFalse(
            all.contains(where: { $0.id == created.id }),
            "delete(id:) must remove the target card from the store"
        )
        XCTAssertTrue(vm.items.isEmpty)
    }
}
