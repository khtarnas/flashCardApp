//
//  CoreDataCardStoreTests.swift
//  HanaHouTests
//
//  Feature: card-management
//  Covers behaviors: C1, C2, C3, C4, C5, C6, C9, C10, B11-C
//  Validates requirements: 1.3, 1.4, 1.6, 1.7, 2.1, 3.2, 3.3, 3.4, 3.5, 4.2, 4.3, 4.4, 5.5, 6.1, 6.2, 7.1–7.10
//

import XCTest
import CoreData
import Combine
@testable import HanaHou

final class CoreDataCardStoreTests: XCTestCase {

    private var container: NSPersistentContainer!
    private var context: NSManagedObjectContext!
    private var cancellables: Set<AnyCancellable> = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = Self.makeInMemoryContainer()
        context = container.viewContext
        cancellables = []
    }

    override func tearDown() {
        container = nil
        context = nil
        cancellables = []
        super.tearDown()
    }

    // MARK: - Helpers

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

    /// Returns a mutable clock closure plus a setter so tests can advance time.
    private func makeMutableClock(initial: Date) -> (clock: () -> Date, set: (Date) -> Void) {
        final class Box { var date: Date; init(_ d: Date) { self.date = d } }
        let box = Box(initial)
        return ({ box.date }, { box.date = $0 })
    }

    /// Waits briefly so a PassthroughSubject / `NSManagedObjectContextDidSave`
    /// notification has a chance to dispatch on the next run-loop turn.
    private func waitBriefly(_ timeout: TimeInterval = 0.05) {
        let exp = expectation(description: "brief wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// Sort cards deterministically by (createdAt, id) for order-insensitive assertions.
    private func sorted(_ cards: [CardSnapshot]) -> [CardSnapshot] {
        cards.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    }

    // MARK: - C3: Create round-trip
    // Requirements: 1.6, 1.7, 2.1, 7.1, 7.3, 7.4, 7.5

    func test_create_validTextAndDeckIds_returnsSnapshotAndPersists() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let deckStore = CoreDataDeckStore(context: context, clock: { t })
        let cardStore = CoreDataCardStore(context: context, clock: { t })

        let deckD = try deckStore.create(makeDeckDraft(name: "Japanese"))

        let snapshot = try cardStore.create(
            frontText: "front",
            backText: "back",
            deckIds: [deckD.id]
        )

        XCTAssertEqual(snapshot.frontText, "front")
        XCTAssertEqual(snapshot.backText, "back")
        XCTAssertEqual(snapshot.deckIds, [deckD.id])
        XCTAssertEqual(snapshot.createdAt, t)
        XCTAssertEqual(snapshot.updatedAt, t)
        XCTAssertEqual(snapshot.createdAt, snapshot.updatedAt)

        let all = try cardStore.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, snapshot.id)

        let inDeckD = try cardStore.fetchInDeck(deckId: deckD.id)
        XCTAssertEqual(inDeckD.count, 1)
        XCTAssertEqual(inDeckD.first?.id, snapshot.id)
    }

    func test_create_setsCreatedAtAndUpdatedAtFromInjectedClock() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let deckStore = CoreDataDeckStore(context: context, clock: { t })
        let cardStore = CoreDataCardStore(context: context, clock: { t })
        let deckD = try deckStore.create(makeDeckDraft(name: "Japanese"))

        let snapshot = try cardStore.create(
            frontText: "front",
            backText: "back",
            deckIds: [deckD.id]
        )

        XCTAssertEqual(snapshot.createdAt, t)
        XCTAssertEqual(snapshot.updatedAt, t)
        XCTAssertEqual(snapshot.createdAt, snapshot.updatedAt)
    }

    func test_create_withEmptyDeckIds_createsOrphan() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let cardStore = CoreDataCardStore(context: context, clock: { t })

        let snapshot = try cardStore.create(
            frontText: "front",
            backText: "back",
            deckIds: []
        )

        XCTAssertTrue(snapshot.deckIds.isEmpty)

        let all = try cardStore.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, snapshot.id)
        XCTAssertTrue(all.first?.deckIds.isEmpty ?? false)

        let inArbitraryDeck = try cardStore.fetchInDeck(deckId: UUID())
        XCTAssertTrue(
            inArbitraryDeck.isEmpty,
            "An orphan card must not appear in fetchInDeck for any deck id"
        )
    }

    func test_fetchInDeck_onlyReturnsCardsAssociatedWithThatDeck() throws {
        // Exercises the many-to-many `decks` predicate
        // (`NSPredicate(format: "ANY decks.id == %@", ...)` — Req 7.2, 7.4).
        let t = Date(timeIntervalSince1970: 1_000)
        let deckStore = CoreDataDeckStore(context: context, clock: { t })
        let cardStore = CoreDataCardStore(context: context, clock: { t })

        let deckD = try deckStore.create(makeDeckDraft(name: "Japanese"))
        let deckE = try deckStore.create(makeDeckDraft(name: "Korean"))
        let unrelated = UUID()

        let cardInDOnly = try cardStore.create(
            frontText: "d-only",
            backText: "d",
            deckIds: [deckD.id]
        )
        let cardInEOnly = try cardStore.create(
            frontText: "e-only",
            backText: "e",
            deckIds: [deckE.id]
        )
        let cardInBoth = try cardStore.create(
            frontText: "both",
            backText: "b",
            deckIds: [deckD.id, deckE.id]
        )

        let inD = try cardStore.fetchInDeck(deckId: deckD.id)
        let inE = try cardStore.fetchInDeck(deckId: deckE.id)
        let inUnrelated = try cardStore.fetchInDeck(deckId: unrelated)

        XCTAssertEqual(
            Set(inD.map(\.id)),
            Set([cardInDOnly.id, cardInBoth.id]),
            "fetchInDeck(D) must return the D-only card and the card in both decks"
        )
        XCTAssertEqual(
            Set(inE.map(\.id)),
            Set([cardInEOnly.id, cardInBoth.id]),
            "fetchInDeck(E) must return the E-only card and the card in both decks"
        )
        XCTAssertTrue(
            inUnrelated.isEmpty,
            "fetchInDeck for a deck id unrelated to any stored card must be empty"
        )
    }

    // MARK: - C1 / C2: Create validation
    // Requirements: 1.3, 1.4

    func test_create_emptyFront_throwsMissingFront() throws {
        let cardStore = CoreDataCardStore(context: context, clock: { Date(timeIntervalSince1970: 1_000) })
        let before = try cardStore.fetchAll()

        XCTAssertThrowsError(
            try cardStore.create(frontText: "", backText: "back", deckIds: [UUID()])
        ) { error in
            guard let textError = error as? CardTextError, case .missingFront = textError else {
                XCTFail("Expected CardTextError.missingFront, got \(error)")
                return
            }
        }

        let after = try cardStore.fetchAll()
        XCTAssertEqual(sorted(after).map(\.id), sorted(before).map(\.id))
    }

    func test_create_emptyBack_throwsMissingBack() throws {
        let cardStore = CoreDataCardStore(context: context, clock: { Date(timeIntervalSince1970: 1_000) })
        let before = try cardStore.fetchAll()

        XCTAssertThrowsError(
            try cardStore.create(frontText: "front", backText: "", deckIds: [UUID()])
        ) { error in
            guard let textError = error as? CardTextError, case .missingBack = textError else {
                XCTFail("Expected CardTextError.missingBack, got \(error)")
                return
            }
        }

        let after = try cardStore.fetchAll()
        XCTAssertEqual(sorted(after).map(\.id), sorted(before).map(\.id))
    }

    func test_create_bothEmpty_throwsMissingFront() throws {
        // Front is checked before back (design §Domain Layer).
        let cardStore = CoreDataCardStore(context: context, clock: { Date(timeIntervalSince1970: 1_000) })

        XCTAssertThrowsError(
            try cardStore.create(frontText: "", backText: "", deckIds: [UUID()])
        ) { error in
            guard let textError = error as? CardTextError, case .missingFront = textError else {
                XCTFail("Expected CardTextError.missingFront (front-priority), got \(error)")
                return
            }
        }

        let after = try cardStore.fetchAll()
        XCTAssertTrue(after.isEmpty)
    }

    // MARK: - C4: Edit round-trip
    // Requirements: 3.2, 3.5, 7.6

    func test_update_validText_preservesIdCreatedAtDeckIds_bumpsUpdatedAt() throws {
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        let (clock, setClock) = makeMutableClock(initial: t1)
        let deckStore = CoreDataDeckStore(context: context, clock: clock)
        let cardStore = CoreDataCardStore(context: context, clock: clock)

        let deckD = try deckStore.create(makeDeckDraft(name: "Japanese"))
        let original = try cardStore.create(
            frontText: "front",
            backText: "back",
            deckIds: [deckD.id]
        )
        XCTAssertEqual(original.createdAt, t1)
        XCTAssertEqual(original.updatedAt, t1)

        setClock(t2)
        try cardStore.update(id: original.id, frontText: "front 2", backText: "back 2")

        let all = try cardStore.fetchAll()
        XCTAssertEqual(all.count, 1)

        let updated = try XCTUnwrap(all.first)
        XCTAssertEqual(updated.id, original.id, "id must be preserved across updates")
        XCTAssertEqual(updated.createdAt, t1, "createdAt must be preserved across updates")
        XCTAssertEqual(updated.updatedAt, t2, "updatedAt must be set to the clock's current value")
        XCTAssertEqual(updated.deckIds, [deckD.id], "deckIds must be preserved across updates")
        XCTAssertEqual(updated.frontText, "front 2")
        XCTAssertEqual(updated.backText, "back 2")
    }

    // MARK: - C1 / C2 / C9: Update validation + unknown id
    // Requirements: 1.3, 1.4, 3.3, 3.4, 7.9

    func test_update_emptyFront_throwsMissingFront_noMutation() throws {
        let cardStore = CoreDataCardStore(context: context, clock: { Date(timeIntervalSince1970: 1_000) })
        let original = try cardStore.create(
            frontText: "front",
            backText: "back",
            deckIds: [UUID()]
        )
        let before = try cardStore.fetchAll()

        XCTAssertThrowsError(
            try cardStore.update(id: original.id, frontText: "   ", backText: "back 2")
        ) { error in
            guard let textError = error as? CardTextError, case .missingFront = textError else {
                XCTFail("Expected CardTextError.missingFront, got \(error)")
                return
            }
        }

        let after = try cardStore.fetchAll()
        XCTAssertEqual(sorted(after), sorted(before), "Failed update must not mutate the store")
    }

    func test_update_emptyBack_throwsMissingBack_noMutation() throws {
        let cardStore = CoreDataCardStore(context: context, clock: { Date(timeIntervalSince1970: 1_000) })
        let original = try cardStore.create(
            frontText: "front",
            backText: "back",
            deckIds: [UUID()]
        )
        let before = try cardStore.fetchAll()

        XCTAssertThrowsError(
            try cardStore.update(id: original.id, frontText: "front 2", backText: "\t\n")
        ) { error in
            guard let textError = error as? CardTextError, case .missingBack = textError else {
                XCTFail("Expected CardTextError.missingBack, got \(error)")
                return
            }
        }

        let after = try cardStore.fetchAll()
        XCTAssertEqual(sorted(after), sorted(before), "Failed update must not mutate the store")
    }

    func test_update_unknownId_isSilentNoOp_noEmission() throws {
        let cardStore = CoreDataCardStore(context: context, clock: { Date(timeIntervalSince1970: 1_000) })
        _ = try cardStore.create(
            frontText: "front",
            backText: "back",
            deckIds: [UUID()]
        )
        let before = try cardStore.fetchAll()

        var count = 0
        cardStore.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        XCTAssertNoThrow(
            try cardStore.update(id: UUID(), frontText: "front 2", backText: "back 2")
        )

        waitBriefly()

        let after = try cardStore.fetchAll()
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
        let t = Date(timeIntervalSince1970: 1_000)
        let deckStore = CoreDataDeckStore(context: context, clock: { t })
        let cardStore = CoreDataCardStore(context: context, clock: { t })

        let deckD = try deckStore.create(makeDeckDraft(name: "Japanese"))
        let deckE = try deckStore.create(makeDeckDraft(name: "Korean"))

        let snapshot = try cardStore.create(
            frontText: "front",
            backText: "back",
            deckIds: [deckD.id, deckE.id]
        )

        try cardStore.delete(id: snapshot.id)

        XCTAssertFalse(
            try cardStore.fetchAll().contains(where: { $0.id == snapshot.id }),
            "Deleted card must not appear in fetchAll"
        )
        XCTAssertFalse(
            try cardStore.fetchInDeck(deckId: deckD.id).contains(where: { $0.id == snapshot.id }),
            "Deleted card must not appear in fetchInDeck(D)"
        )
        XCTAssertFalse(
            try cardStore.fetchInDeck(deckId: deckE.id).contains(where: { $0.id == snapshot.id }),
            "Deleted card must not appear in fetchInDeck(E)"
        )

        // The decks themselves must still exist — deleting a card does not
        // delete any deck (Req 4.4).
        let remainingDecks = try deckStore.fetchAll()
        XCTAssertEqual(
            Set(remainingDecks.map(\.id)),
            Set([deckD.id, deckE.id]),
            "Deleting a card must not delete any deck"
        )
    }

    func test_delete_onlyRemovesTargetCard() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let deckStore = CoreDataDeckStore(context: context, clock: { t })
        let cardStore = CoreDataCardStore(context: context, clock: { t })

        let deckD = try deckStore.create(makeDeckDraft(name: "Japanese"))
        let deckE = try deckStore.create(makeDeckDraft(name: "Korean"))

        let card1 = try cardStore.create(
            frontText: "one",
            backText: "1",
            deckIds: [deckD.id]
        )
        let card2 = try cardStore.create(
            frontText: "two",
            backText: "2",
            deckIds: [deckE.id]
        )

        try cardStore.delete(id: card1.id)

        let all = try cardStore.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, card2.id)

        XCTAssertTrue(try cardStore.fetchInDeck(deckId: deckD.id).isEmpty)
        XCTAssertEqual(try cardStore.fetchInDeck(deckId: deckE.id).map(\.id), [card2.id])
    }

    func test_delete_unknownId_isSilentNoOp_noEmission() throws {
        let cardStore = CoreDataCardStore(context: context, clock: { Date(timeIntervalSince1970: 1_000) })
        _ = try cardStore.create(
            frontText: "front",
            backText: "back",
            deckIds: [UUID()]
        )
        let before = try cardStore.fetchAll()

        var count = 0
        cardStore.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        XCTAssertNoThrow(try cardStore.delete(id: UUID()))

        waitBriefly()

        let after = try cardStore.fetchAll()
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
        let cardStore = CoreDataCardStore(context: context, clock: { Date(timeIntervalSince1970: 1_000) })

        var count = 0
        cardStore.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        _ = try cardStore.create(
            frontText: "front",
            backText: "back",
            deckIds: [UUID()]
        )

        waitBriefly()
        XCTAssertGreaterThanOrEqual(count, 1, "Change publisher must emit on successful create")
    }

    func test_changes_emitsOnUpdate() throws {
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        let (clock, setClock) = makeMutableClock(initial: t1)
        let cardStore = CoreDataCardStore(context: context, clock: clock)

        let original = try cardStore.create(
            frontText: "front",
            backText: "back",
            deckIds: [UUID()]
        )

        var count = 0
        cardStore.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        setClock(t2)
        try cardStore.update(id: original.id, frontText: "front 2", backText: "back 2")

        waitBriefly()
        XCTAssertGreaterThanOrEqual(count, 1, "Change publisher must emit on successful update")
    }

    func test_changes_emitsOnDelete() throws {
        let cardStore = CoreDataCardStore(context: context, clock: { Date(timeIntervalSince1970: 1_000) })
        let original = try cardStore.create(
            frontText: "front",
            backText: "back",
            deckIds: [UUID()]
        )

        var count = 0
        cardStore.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        try cardStore.delete(id: original.id)

        waitBriefly()
        XCTAssertGreaterThanOrEqual(count, 1, "Change publisher must emit on successful delete")
    }

    func test_changes_doesNotEmitOnFailedCreate() {
        let cardStore = CoreDataCardStore(context: context, clock: { Date(timeIntervalSince1970: 1_000) })

        var count = 0
        cardStore.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        XCTAssertThrowsError(
            try cardStore.create(frontText: "", backText: "back", deckIds: [UUID()])
        )

        waitBriefly()
        XCTAssertEqual(count, 0, "Change publisher must not emit when a mutation fails validation")
    }

    func test_changes_doesNotEmitOnFailedUpdate() throws {
        let cardStore = CoreDataCardStore(context: context, clock: { Date(timeIntervalSince1970: 1_000) })
        let original = try cardStore.create(
            frontText: "front",
            backText: "back",
            deckIds: [UUID()]
        )

        var count = 0
        cardStore.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        XCTAssertThrowsError(
            try cardStore.update(id: original.id, frontText: "", backText: "back 2")
        )

        waitBriefly()
        XCTAssertEqual(count, 0, "Change publisher must not emit when a mutation fails validation")
    }

    // MARK: - C6: Orphan on last-deck deletion (shared context)
    // Requirements: 6.1, 6.2, 7.8

    func test_cardBecomesOrphan_whenOnlyAssociatedDeckIsDeleted() throws {
        // Build both stores against the SAME viewContext so the
        // NSManagedObjectContextDidSave notification emitted by the deck
        // deletion reaches the card store's observer.
        let t = Date(timeIntervalSince1970: 1_000)
        let deckStore = CoreDataDeckStore(context: context, clock: { t })
        let cardStore = CoreDataCardStore(context: context, clock: { t })

        let deckD = try deckStore.create(makeDeckDraft(name: "Japanese"))
        let card = try cardStore.create(
            frontText: "front",
            backText: "back",
            deckIds: [deckD.id]
        )

        // Subscribe AFTER the card was created so the counter starts at 0
        // before the deck deletion.
        var count = 0
        cardStore.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        XCTAssertEqual(count, 0, "Baseline: no changes-emissions observed before the deck deletion")

        // Act: delete the card's only associated deck.
        try deckStore.delete(id: deckD.id)

        // The shared-context save notification dispatches on the next
        // run-loop turn; give it a chance to propagate.
        waitBriefly()

        // Assert: the card is still present but is now an orphan.
        let all = try cardStore.fetchAll()
        let refreshed = try XCTUnwrap(
            all.first(where: { $0.id == card.id }),
            "Card must still exist after its only deck is deleted (Req 6.1)"
        )
        XCTAssertTrue(
            refreshed.deckIds.isEmpty,
            "Card must be an orphan after its only deck is deleted (Req 6.1)"
        )

        // Assert: the deck is gone.
        XCTAssertTrue(try deckStore.fetchAll().isEmpty)

        // Assert: the card store observed the deck-deletion save.
        XCTAssertGreaterThanOrEqual(
            count,
            1,
            "CoreDataCardStore.changes must fire after a deck deletion on the shared context (Req 7.8)"
        )
    }

    // MARK: - B11-C: Deck deletion preserves cards still attached to other decks
    // Requirements: 4.4, 6.1, 6.2, 7.2, 7.4

    func test_deckDeletion_detachesCard_butCardRemainsAttachedToOtherDeck() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let deckStore = CoreDataDeckStore(context: context, clock: { t })
        let cardStore = CoreDataCardStore(context: context, clock: { t })

        let deckD = try deckStore.create(makeDeckDraft(name: "Japanese"))
        let deckE = try deckStore.create(makeDeckDraft(name: "Korean"))

        let card = try cardStore.create(
            frontText: "front",
            backText: "back",
            deckIds: [deckD.id, deckE.id]
        )

        // Act: delete deck D; card must remain attached to deck E.
        try deckStore.delete(id: deckD.id)

        waitBriefly()

        // Assert (card-side API): the card is still in fetchAll with deckIds == [E].
        let all = try cardStore.fetchAll()
        let refreshed = try XCTUnwrap(
            all.first(where: { $0.id == card.id }),
            "Card must still exist after one of two decks is deleted (Req 4.4 / 6.1)"
        )
        XCTAssertEqual(
            refreshed.deckIds,
            [deckE.id],
            "Card must remain attached only to the undeleted deck E"
        )

        // Assert (deck-side API): deck E is untouched.
        let remainingDecks = try deckStore.fetchAll()
        XCTAssertEqual(remainingDecks.count, 1)
        XCTAssertEqual(remainingDecks.first?.id, deckE.id)
        XCTAssertEqual(remainingDecks.first?.name, "Korean")

        // Assert (predicate on many-to-many): fetchInDeck(E) returns the card.
        let inE = try cardStore.fetchInDeck(deckId: deckE.id)
        XCTAssertEqual(inE.map(\.id), [card.id])

        // And fetchInDeck(D) is empty — D is gone.
        XCTAssertTrue(
            try cardStore.fetchInDeck(deckId: deckD.id).isEmpty,
            "The deleted deck must have no cards reachable via fetchInDeck"
        )
    }
}
