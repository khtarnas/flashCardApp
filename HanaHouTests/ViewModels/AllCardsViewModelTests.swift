//
//  AllCardsViewModelTests.swift
//  HanaHouTests
//
//  Feature: card-management
//  Covers behaviors: C3, C4, C5, C6, C11, C12, B11-C
//  Validates requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 6.1, 6.2, 7.3
//

import XCTest
import Combine
import CoreData
@testable import HanaHou

/// Reverse-ordering stub so tests can assert strategy-independence — the
/// All Cards view model must use whatever `CardOrderingStrategy` it is
/// handed at init time, without reapplying its own ordering.
private struct ReverseCardOrderingStub: CardOrderingStrategy {
    func order(_ cards: [CardSnapshot]) -> [CardSnapshot] { cards.reversed() }
}

@MainActor
final class AllCardsViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeMutableClock(initial: Date) -> (clock: () -> Date, set: (Date) -> Void) {
        final class Box { var date: Date; init(_ d: Date) { self.date = d } }
        let box = Box(initial)
        return ({ box.date }, { box.date = $0 })
    }

    private func waitBriefly(_ timeout: TimeInterval = 0.05) {
        let exp = expectation(description: "brief wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    private func rowIds(_ items: [CardRowItem]) -> [UUID] { items.map(\.id) }

    private static func makeInMemoryContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "HanaHou")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError = loadError {
            fatalError("Failed to load in-memory store: \(loadError)")
        }
        return container
    }

    private func makeDeckDraft(
        name: String = "Japanese",
        front: Language = .english,
        back: Language = .japanese
    ) -> DeckDraft {
        DeckDraft(name: name, frontLanguage: front, backLanguage: back)
    }

    // MARK: - C12: Empty state
    // Requirements: 5.6

    func test_items_isEmpty_whenStoreIsEmpty() {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })

        let vm = AllCardsViewModel(store: store, strategy: CardCreationDateAscendingOrdering())

        XCTAssertTrue(vm.items.isEmpty)
    }

    // MARK: - C3: Create propagates (including across deck membership)
    // Requirements: 5.2, 5.3, 5.5

    func test_items_includesCardCreatedInAnyDeck() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckA = UUID()
        let deckB = UUID()

        let vm = AllCardsViewModel(store: store, strategy: CardCreationDateAscendingOrdering())
        XCTAssertTrue(vm.items.isEmpty)

        let inA = try store.create(frontText: "a", backText: "1", deckIds: [deckA])
        let inB = try store.create(frontText: "b", backText: "2", deckIds: [deckB])
        let inBoth = try store.create(frontText: "c", backText: "3", deckIds: [deckA, deckB])

        waitBriefly()

        XCTAssertEqual(Set(rowIds(vm.items)), Set([inA.id, inB.id, inBoth.id]))
    }

    func test_items_includesOrphanCard() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })

        let vm = AllCardsViewModel(store: store, strategy: CardCreationDateAscendingOrdering())

        let orphan = try store.create(frontText: "orphan", backText: "0", deckIds: [])

        waitBriefly()

        XCTAssertEqual(vm.items.count, 1)
        let row = try XCTUnwrap(vm.items.first)
        XCTAssertEqual(row.id, orphan.id)
        XCTAssertTrue(row.isOrphan, "A card with no deckIds must be flagged as an orphan in the row")
    }

    // MARK: - C4: Update propagates
    // Requirements: 5.5

    func test_items_reflectsEditedCardText() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckA = UUID()

        let vm = AllCardsViewModel(store: store, strategy: CardCreationDateAscendingOrdering())

        let created = try store.create(frontText: "old", backText: "0", deckIds: [deckA])
        waitBriefly()

        try store.update(id: created.id, frontText: "new", backText: "1")
        waitBriefly()

        XCTAssertEqual(vm.items.count, 1)
        let row = try XCTUnwrap(vm.items.first)
        XCTAssertEqual(row.id, created.id)
        XCTAssertEqual(row.frontText, "new")
        XCTAssertEqual(row.backText, "1")
    }

    // MARK: - C5: Delete propagates
    // Requirements: 5.5

    func test_items_removesDeletedCard() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckA = UUID()

        let vm = AllCardsViewModel(store: store, strategy: CardCreationDateAscendingOrdering())

        let first = try store.create(frontText: "one", backText: "1", deckIds: [deckA])
        let second = try store.create(frontText: "two", backText: "2", deckIds: [deckA])
        waitBriefly()
        XCTAssertEqual(Set(rowIds(vm.items)), Set([first.id, second.id]))

        try store.delete(id: first.id)
        waitBriefly()

        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(vm.items.first?.id, second.id)
    }

    // MARK: - C6: Card becomes an orphan when its last associated deck is deleted
    // In-memory variant using `simulateDeckDeleted(deckId:)` (per design
    // §Persistence Layer / "InMemoryCardStore" — fast path for view-model tests).
    // Requirements: 6.1, 6.2

    func test_items_reflectsOrphaningWhenLastDeckDeleted_inMemory() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckA = UUID()

        let vm = AllCardsViewModel(store: store, strategy: CardCreationDateAscendingOrdering())

        let card = try store.create(frontText: "front", backText: "back", deckIds: [deckA])
        waitBriefly()
        XCTAssertEqual(vm.items.count, 1)
        XCTAssertFalse(vm.items.first?.isOrphan ?? true)

        // Simulate the shared-context deck-deletion path.
        store.simulateDeckDeleted(deckId: deckA)
        waitBriefly()

        // The card is still present, but now an orphan.
        XCTAssertEqual(vm.items.count, 1)
        let row = try XCTUnwrap(vm.items.first)
        XCTAssertEqual(row.id, card.id)
        XCTAssertTrue(
            row.isOrphan,
            "Card must be marked as orphan after its last associated deck is deleted (Req 6.1)"
        )
    }

    /// Core-Data-backed variant of C6 — exercises the real
    /// `NSManagedObjectContextDidSave` flow between `CoreDataDeckStore` and
    /// `CoreDataCardStore` sharing a single `NSManagedObjectContext`.
    func test_items_reflectsOrphaningWhenLastDeckDeleted_coreData() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let container = Self.makeInMemoryContainer()
        let context = container.viewContext
        let deckStore = CoreDataDeckStore(context: context, clock: { t })
        let cardStore = CoreDataCardStore(context: context, clock: { t })

        let vm = AllCardsViewModel(store: cardStore, strategy: CardCreationDateAscendingOrdering())

        let deckD = try deckStore.create(makeDeckDraft(name: "Japanese"))
        let card = try cardStore.create(frontText: "front", backText: "back", deckIds: [deckD.id])
        waitBriefly()
        XCTAssertEqual(vm.items.count, 1)
        XCTAssertFalse(
            vm.items.first?.isOrphan ?? true,
            "Card must not be an orphan while deck D exists"
        )

        try deckStore.delete(id: deckD.id)
        waitBriefly()

        XCTAssertEqual(vm.items.count, 1, "Card must remain in All Cards after deck deletion")
        let row = try XCTUnwrap(vm.items.first)
        XCTAssertEqual(row.id, card.id)
        XCTAssertTrue(
            row.isOrphan,
            "Card must be flagged as orphan once its only deck is deleted (Req 6.1, 6.2)"
        )
    }

    // MARK: - B11-C: Deck deletion preserves cards still attached to other decks
    // Requirements: 6.1, 6.2, 7.2, 7.4

    func test_items_preservesCard_whenDeletedDeckIsNotTheLastAssociation_coreData() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let container = Self.makeInMemoryContainer()
        let context = container.viewContext
        let deckStore = CoreDataDeckStore(context: context, clock: { t })
        let cardStore = CoreDataCardStore(context: context, clock: { t })

        let vm = AllCardsViewModel(store: cardStore, strategy: CardCreationDateAscendingOrdering())

        let deckD = try deckStore.create(makeDeckDraft(name: "Japanese"))
        let deckE = try deckStore.create(makeDeckDraft(name: "Korean"))
        let card = try cardStore.create(
            frontText: "front",
            backText: "back",
            deckIds: [deckD.id, deckE.id]
        )
        waitBriefly()
        XCTAssertEqual(vm.items.count, 1)
        XCTAssertFalse(vm.items.first?.isOrphan ?? true)

        try deckStore.delete(id: deckD.id)
        waitBriefly()

        XCTAssertEqual(vm.items.count, 1, "Card must remain reachable after one of two decks is deleted")
        let row = try XCTUnwrap(vm.items.first)
        XCTAssertEqual(row.id, card.id)
        XCTAssertFalse(
            row.isOrphan,
            "Card must NOT be an orphan while it is still attached to deck E"
        )
    }

    // MARK: - C11: changes subscription drives reloads
    // Requirements: 5.5

    func test_items_updatesAfterEveryMutation() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckA = UUID()

        let vm = AllCardsViewModel(store: store, strategy: CardCreationDateAscendingOrdering())
        XCTAssertTrue(vm.items.isEmpty)

        let created = try store.create(frontText: "front", backText: "back", deckIds: [deckA])
        waitBriefly()
        XCTAssertEqual(vm.items.count, 1)

        try store.update(id: created.id, frontText: "front 2", backText: "back 2")
        waitBriefly()
        XCTAssertEqual(vm.items.first?.frontText, "front 2")
        XCTAssertEqual(vm.items.first?.backText, "back 2")

        try store.delete(id: created.id)
        waitBriefly()
        XCTAssertTrue(vm.items.isEmpty)
    }

    // MARK: - snapshotsById lookup

    func test_snapshotForRowId_returnsMatchingSnapshot() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckA = UUID()

        let vm = AllCardsViewModel(store: store, strategy: CardCreationDateAscendingOrdering())

        let created = try store.create(frontText: "front", backText: "back", deckIds: [deckA])
        waitBriefly()

        let resolved = vm.snapshot(forRowId: created.id)
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.id, created.id)
        XCTAssertEqual(resolved?.frontText, "front")

        XCTAssertNil(vm.snapshot(forRowId: UUID()))
    }

    // MARK: - Strategy is used verbatim

    func test_items_usesInjectedStrategyVerbatim() throws {
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
        let vm = AllCardsViewModel(store: store, strategy: strategy)

        let expectedIds = strategy.order(try store.fetchAll()).map(\.id)
        XCTAssertEqual(rowIds(vm.items), expectedIds)
    }

    // MARK: - delete(id:) dispatch

    func test_delete_dispatchesToStore() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckA = UUID()

        let vm = AllCardsViewModel(store: store, strategy: CardCreationDateAscendingOrdering())

        let created = try store.create(frontText: "front", backText: "back", deckIds: [deckA])
        waitBriefly()

        try vm.delete(id: created.id)
        waitBriefly()

        XCTAssertTrue(try store.fetchAll().isEmpty)
        XCTAssertTrue(vm.items.isEmpty)
    }
}
