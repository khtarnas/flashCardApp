//
//  InMemoryCardStoreTests.swift
//  HanaHouTests
//
//  Feature: card-management
//  Covers behaviors: C1, C2, C3, C4, C5, C9, C10 (plus in-memory simulateDeckDeleted helper)
//  Validates requirements: 1.3, 1.4, 1.6, 1.7, 2.1, 3.2, 3.3, 3.4, 3.5, 4.2, 4.3, 4.4, 5.5, 7.1, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9
//

import XCTest
import Combine
@testable import HanaHou

final class InMemoryCardStoreTests: XCTestCase {

    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    // MARK: - Helpers

    /// Returns a mutable clock closure plus a setter, so tests can advance time.
    private func makeMutableClock(initial: Date) -> (clock: () -> Date, set: (Date) -> Void) {
        // Use a class wrapper so the closure captures a mutable reference.
        final class Box { var date: Date; init(_ d: Date) { self.date = d } }
        let box = Box(initial)
        return ({ box.date }, { box.date = $0 })
    }

    /// Sort cards deterministically by (createdAt, id) for order-insensitive assertions.
    private func sorted(_ cards: [CardSnapshot]) -> [CardSnapshot] {
        cards.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    }

    /// Waits briefly so a PassthroughSubject has a chance to emit, then returns.
    private func waitBriefly(_ timeout: TimeInterval = 0.05) {
        let exp = expectation(description: "brief wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    // MARK: - C3: Create round-trip
    // Requirements: 1.6, 1.7, 2.1, 7.1, 7.3, 7.4, 7.5

    func test_create_validTextAndDeckIds_returnsSnapshotAndPersists() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let store = InMemoryCardStore(clock: { t })
        let deckA = UUID()
        let deckB = UUID()

        let snapshot = try store.create(
            frontText: "front",
            backText: "back",
            deckIds: [deckA, deckB]
        )

        XCTAssertEqual(snapshot.frontText, "front")
        XCTAssertEqual(snapshot.backText, "back")
        XCTAssertEqual(snapshot.deckIds, [deckA, deckB])

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, snapshot.id)

        let inDeckA = try store.fetchInDeck(deckId: deckA)
        XCTAssertEqual(inDeckA.count, 1)
        XCTAssertEqual(inDeckA.first?.id, snapshot.id)
    }

    func test_create_setsCreatedAtAndUpdatedAtFromInjectedClock() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let store = InMemoryCardStore(clock: { t })

        let snapshot = try store.create(
            frontText: "front",
            backText: "back",
            deckIds: [UUID()]
        )

        XCTAssertEqual(snapshot.createdAt, t)
        XCTAssertEqual(snapshot.updatedAt, t)
        XCTAssertEqual(snapshot.createdAt, snapshot.updatedAt)
    }

    func test_create_withEmptyDeckIds_createsOrphan() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })

        let snapshot = try store.create(
            frontText: "front",
            backText: "back",
            deckIds: []
        )

        XCTAssertTrue(snapshot.deckIds.isEmpty)

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, snapshot.id)

        let inArbitraryDeck = try store.fetchInDeck(deckId: UUID())
        XCTAssertTrue(inArbitraryDeck.isEmpty, "An orphan card must not appear in fetchInDeck for any deck id")
    }

    func test_create_returnedSnapshotAppearsInFetchInDeckForEveryAssociatedDeck() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckA = UUID()
        let deckB = UUID()
        let unrelatedC = UUID()

        let snapshot = try store.create(
            frontText: "front",
            backText: "back",
            deckIds: [deckA, deckB]
        )

        let inA = try store.fetchInDeck(deckId: deckA)
        let inB = try store.fetchInDeck(deckId: deckB)
        let inC = try store.fetchInDeck(deckId: unrelatedC)

        XCTAssertEqual(inA.map(\.id), [snapshot.id])
        XCTAssertEqual(inB.map(\.id), [snapshot.id])
        XCTAssertTrue(inC.isEmpty)
    }

    // MARK: - C1 / C2: Create validation
    // Requirements: 1.3, 1.4

    func test_create_emptyFront_throwsMissingFront() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let before = try store.fetchAll()

        XCTAssertThrowsError(
            try store.create(frontText: "", backText: "back", deckIds: [UUID()])
        ) { error in
            guard let textError = error as? CardTextError, case .missingFront = textError else {
                XCTFail("Expected CardTextError.missingFront, got \(error)")
                return
            }
        }

        let after = try store.fetchAll()
        XCTAssertEqual(sorted(after).map(\.id), sorted(before).map(\.id))
    }

    func test_create_whitespaceOnlyFront_throwsMissingFront() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })

        // The validator (task 2.2) trims `.whitespacesAndNewlines`, which covers
        // spaces, tabs, and newlines. Picking one representative whitespace-only
        // input here; the full matrix (""/"   "/"\t"/"\n"/" \t\n ") is already
        // exercised in `CardTextValidatorTests`.
        XCTAssertThrowsError(
            try store.create(frontText: " \t\n ", backText: "back", deckIds: [UUID()])
        ) { error in
            guard let textError = error as? CardTextError, case .missingFront = textError else {
                XCTFail("Expected CardTextError.missingFront, got \(error)")
                return
            }
        }

        let after = try store.fetchAll()
        XCTAssertTrue(after.isEmpty)
    }

    func test_create_emptyBack_throwsMissingBack() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let before = try store.fetchAll()

        XCTAssertThrowsError(
            try store.create(frontText: "front", backText: "", deckIds: [UUID()])
        ) { error in
            guard let textError = error as? CardTextError, case .missingBack = textError else {
                XCTFail("Expected CardTextError.missingBack, got \(error)")
                return
            }
        }

        let after = try store.fetchAll()
        XCTAssertEqual(sorted(after).map(\.id), sorted(before).map(\.id))
    }

    func test_create_bothEmpty_throwsMissingFront() throws {
        // Front is checked before back (design §Domain Layer).
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })

        XCTAssertThrowsError(
            try store.create(frontText: "", backText: "", deckIds: [UUID()])
        ) { error in
            guard let textError = error as? CardTextError, case .missingFront = textError else {
                XCTFail("Expected CardTextError.missingFront (front-priority), got \(error)")
                return
            }
        }

        let after = try store.fetchAll()
        XCTAssertTrue(after.isEmpty)
    }

    // MARK: - C4: Edit round-trip
    // Requirements: 3.2, 3.5, 7.6

    func test_update_validText_preservesIdCreatedAtDeckIds_bumpsUpdatedAt() throws {
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        let (clock, setClock) = makeMutableClock(initial: t1)
        let store = InMemoryCardStore(clock: clock)
        let deckA = UUID()

        let original = try store.create(
            frontText: "front",
            backText: "back",
            deckIds: [deckA]
        )
        XCTAssertEqual(original.createdAt, t1)
        XCTAssertEqual(original.updatedAt, t1)

        setClock(t2)
        try store.update(id: original.id, frontText: "front 2", backText: "back 2")

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 1)

        let updated = try XCTUnwrap(all.first)
        XCTAssertEqual(updated.id, original.id, "id must be preserved across updates")
        XCTAssertEqual(updated.createdAt, t1, "createdAt must be preserved across updates")
        XCTAssertEqual(updated.updatedAt, t2, "updatedAt must be set to the clock's current value")
        XCTAssertEqual(Set(updated.deckIds), Set([deckA]), "deckIds must be preserved across updates")
        XCTAssertEqual(updated.frontText, "front 2")
        XCTAssertEqual(updated.backText, "back 2")
    }

    func test_update_emptyFront_throwsMissingFront_noMutation() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let original = try store.create(
            frontText: "front",
            backText: "back",
            deckIds: [UUID()]
        )
        let before = try store.fetchAll()

        XCTAssertThrowsError(
            try store.update(id: original.id, frontText: "   ", backText: "back 2")
        ) { error in
            guard let textError = error as? CardTextError, case .missingFront = textError else {
                XCTFail("Expected CardTextError.missingFront, got \(error)")
                return
            }
        }

        let after = try store.fetchAll()
        XCTAssertEqual(sorted(after), sorted(before), "Failed update must not mutate the store")
    }

    func test_update_emptyBack_throwsMissingBack_noMutation() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let original = try store.create(
            frontText: "front",
            backText: "back",
            deckIds: [UUID()]
        )
        let before = try store.fetchAll()

        XCTAssertThrowsError(
            try store.update(id: original.id, frontText: "front 2", backText: "\t\n")
        ) { error in
            guard let textError = error as? CardTextError, case .missingBack = textError else {
                XCTFail("Expected CardTextError.missingBack, got \(error)")
                return
            }
        }

        let after = try store.fetchAll()
        XCTAssertEqual(sorted(after), sorted(before), "Failed update must not mutate the store")
    }

    func test_update_unknownId_isSilentNoOp_noEmission() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        _ = try store.create(
            frontText: "front",
            backText: "back",
            deckIds: [UUID()]
        )
        let before = try store.fetchAll()

        var count = 0
        store.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        XCTAssertNoThrow(
            try store.update(id: UUID(), frontText: "front 2", backText: "back 2")
        )

        waitBriefly()

        let after = try store.fetchAll()
        XCTAssertEqual(
            sorted(after),
            sorted(before),
            "Updating a non-existent id must leave the store unchanged"
        )
        XCTAssertEqual(count, 0, "Change publisher must not emit for an unknown-id no-op update")
    }

    // MARK: - C5: Delete
    // Requirements: 4.2, 4.3, 4.4

    func test_delete_existingCard_removesFromFetchAll_andEveryFetchInDeck() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckA = UUID()
        let deckB = UUID()

        let snapshot = try store.create(
            frontText: "front",
            backText: "back",
            deckIds: [deckA, deckB]
        )

        try store.delete(id: snapshot.id)

        XCTAssertTrue(try store.fetchAll().isEmpty)
        XCTAssertTrue(try store.fetchInDeck(deckId: deckA).isEmpty)
        XCTAssertTrue(try store.fetchInDeck(deckId: deckB).isEmpty)
    }

    func test_delete_onlyRemovesTargetCard() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckA = UUID()
        let deckB = UUID()

        let card1 = try store.create(
            frontText: "one",
            backText: "1",
            deckIds: [deckA]
        )
        let card2 = try store.create(
            frontText: "two",
            backText: "2",
            deckIds: [deckB]
        )

        try store.delete(id: card1.id)

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, card2.id)

        XCTAssertTrue(try store.fetchInDeck(deckId: deckA).isEmpty)
        XCTAssertEqual(try store.fetchInDeck(deckId: deckB).map(\.id), [card2.id])
    }

    func test_delete_unknownId_isSilentNoOp_noEmission() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        _ = try store.create(
            frontText: "front",
            backText: "back",
            deckIds: [UUID()]
        )
        let before = try store.fetchAll()

        var count = 0
        store.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        XCTAssertNoThrow(try store.delete(id: UUID()))

        waitBriefly()

        let after = try store.fetchAll()
        XCTAssertEqual(
            sorted(after),
            sorted(before),
            "Deleting a non-existent id must leave the store unchanged"
        )
        XCTAssertEqual(count, 0, "Change publisher must not emit for an unknown-id no-op delete")
    }

    // MARK: - C10: Change publisher emission
    // Requirements: 7.8, 7.9

    func test_changes_emitsOnCreate() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })

        var count = 0
        store.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        _ = try store.create(
            frontText: "front",
            backText: "back",
            deckIds: [UUID()]
        )

        waitBriefly()
        XCTAssertEqual(count, 1)
    }

    func test_changes_emitsOnUpdate() throws {
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        let (clock, setClock) = makeMutableClock(initial: t1)
        let store = InMemoryCardStore(clock: clock)
        let original = try store.create(
            frontText: "front",
            backText: "back",
            deckIds: [UUID()]
        )

        var count = 0
        store.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        setClock(t2)
        try store.update(id: original.id, frontText: "front 2", backText: "back 2")

        waitBriefly()
        XCTAssertEqual(count, 1)
    }

    func test_changes_emitsOnDelete() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let original = try store.create(
            frontText: "front",
            backText: "back",
            deckIds: [UUID()]
        )

        var count = 0
        store.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        try store.delete(id: original.id)

        waitBriefly()
        XCTAssertEqual(count, 1)
    }

    func test_changes_doesNotEmitOnFailedCreate() {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })

        var count = 0
        store.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        XCTAssertThrowsError(
            try store.create(frontText: "", backText: "back", deckIds: [UUID()])
        )

        waitBriefly()
        XCTAssertEqual(count, 0, "Change publisher must not emit when a mutation fails validation")
    }

    func test_changes_doesNotEmitOnFailedUpdate() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let original = try store.create(
            frontText: "front",
            backText: "back",
            deckIds: [UUID()]
        )

        var count = 0
        store.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        XCTAssertThrowsError(
            try store.update(id: original.id, frontText: "", backText: "back 2")
        )

        waitBriefly()
        XCTAssertEqual(count, 0, "Change publisher must not emit when a mutation fails validation")
    }

    func test_changes_doesNotEmitOnUnknownIdUpdate() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        _ = try store.create(
            frontText: "front",
            backText: "back",
            deckIds: [UUID()]
        )

        var count = 0
        store.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        XCTAssertNoThrow(
            try store.update(id: UUID(), frontText: "front 2", backText: "back 2")
        )

        waitBriefly()
        XCTAssertEqual(count, 0, "Change publisher must not emit for an unknown-id no-op update")
    }

    func test_changes_doesNotEmitOnUnknownIdDelete() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        _ = try store.create(
            frontText: "front",
            backText: "back",
            deckIds: [UUID()]
        )

        var count = 0
        store.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        XCTAssertNoThrow(try store.delete(id: UUID()))

        waitBriefly()
        XCTAssertEqual(count, 0, "Change publisher must not emit for an unknown-id no-op delete")
    }

    // MARK: - simulateDeckDeleted (test-only helper)
    // Per design §Persistence Layer / "InMemoryCardStore" — internal helper,
    // not on the `CardStore` protocol. Removes the deck id from every stored
    // snapshot's `deckIds` and emits one `changes` signal when any state
    // actually changes; does not emit when no snapshot contains the id.

    func test_simulateDeckDeleted_removesDeckIdFromEveryStoredSnapshot_andEmitsOnce() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckA = UUID()
        let deckB = UUID()
        let deckC = UUID()

        let card1 = try store.create(
            frontText: "one",
            backText: "1",
            deckIds: [deckA]
        )
        let card2 = try store.create(
            frontText: "two",
            backText: "2",
            deckIds: [deckA, deckB]
        )
        let card3 = try store.create(
            frontText: "three",
            backText: "3",
            deckIds: [deckB, deckC]
        )

        var count = 0
        store.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        store.simulateDeckDeleted(deckId: deckA)

        waitBriefly()

        let all = try store.fetchAll()
        let byId = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

        let updatedCard1 = try XCTUnwrap(byId[card1.id])
        let updatedCard2 = try XCTUnwrap(byId[card2.id])
        let updatedCard3 = try XCTUnwrap(byId[card3.id])

        XCTAssertTrue(updatedCard1.deckIds.isEmpty, "card1 was only in deckA; it must become an orphan")
        XCTAssertEqual(Set(updatedCard2.deckIds), Set([deckB]), "card2 must retain deckB after deckA removal")
        XCTAssertEqual(
            Set(updatedCard3.deckIds),
            Set([deckB, deckC]),
            "card3 had no association with deckA; its deckIds must be untouched"
        )

        XCTAssertEqual(count, 1, "simulateDeckDeleted must emit exactly once when any snapshot changed")
    }

    func test_simulateDeckDeleted_doesNotEmit_whenNoStoredSnapshotContainsTheDeckId() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckB = UUID()
        let unrelatedDeckX = UUID()

        _ = try store.create(
            frontText: "one",
            backText: "1",
            deckIds: [deckB]
        )
        let before = try store.fetchAll()

        var count = 0
        store.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        store.simulateDeckDeleted(deckId: unrelatedDeckX)

        waitBriefly()

        let after = try store.fetchAll()
        XCTAssertEqual(
            sorted(after),
            sorted(before),
            "simulateDeckDeleted with a deck id no snapshot references must not mutate state"
        )
        XCTAssertEqual(
            count,
            0,
            "simulateDeckDeleted must not emit when nothing changed (parity with 'emit only on state change')"
        )
    }
}
