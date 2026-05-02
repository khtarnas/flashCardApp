//
//  CoreDataDeckStoreTests.swift
//  HanaHouTests
//
//  Feature: deck-management
//  Covers behaviors: B1 (empty), B2 (reserved), B3 (duplicate w/ self-exclusion), B5 (create round-trip), B6 (edit round-trip), B11 (delete detaches cards without deleting them)
//  Validates requirements: 2.3, 2.5, 2.6, 2.7, 2.8, 3.2, 3.4, 3.5, 3.6, 4.2, 4.3, 5.2, 5.3, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7
//

import XCTest
import CoreData
import Combine
@testable import HanaHou

final class CoreDataDeckStoreTests: XCTestCase {

    private var container: NSPersistentContainer!
    private var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = Self.makeInMemoryContainer()
        context = container.viewContext
    }

    override func tearDown() {
        container = nil
        context = nil
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

    private func makeDraft(
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

    /// Sort decks deterministically for order-insensitive assertions.
    private func sorted(_ decks: [DeckSnapshot]) -> [DeckSnapshot] {
        decks.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    }

    // MARK: - B5: Create round-trip
    // Requirements: 2.3, 2.7, 2.8, 6.4

    func test_create_validDraft_returnsSnapshotAndPersists() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let store = CoreDataDeckStore(context: context, clock: { t })
        let draft = makeDraft()

        let snapshot = try store.create(draft)

        XCTAssertEqual(snapshot.name, draft.name)
        XCTAssertEqual(snapshot.frontLanguage, draft.frontLanguage)
        XCTAssertEqual(snapshot.backLanguage, draft.backLanguage)

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, snapshot.id)
        XCTAssertEqual(all.first?.name, draft.name)
        XCTAssertEqual(all.first?.frontLanguage, draft.frontLanguage)
        XCTAssertEqual(all.first?.backLanguage, draft.backLanguage)
    }

    func test_create_setsCreatedAtAndUpdatedAtFromInjectedClock() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let store = CoreDataDeckStore(context: context, clock: { t })

        let snapshot = try store.create(makeDraft())

        XCTAssertEqual(snapshot.createdAt, t)
        XCTAssertEqual(snapshot.updatedAt, t)
        XCTAssertEqual(snapshot.createdAt, snapshot.updatedAt)
    }

    // MARK: - B1 / B2 / B3: Create validation parity
    // Requirements: 5.2, 5.3, 6.2, 6.3

    func test_create_emptyName_throwsEmpty() throws {
        let store = CoreDataDeckStore(context: context, clock: { Date(timeIntervalSince1970: 1_000) })
        let before = try store.fetchAll()

        XCTAssertThrowsError(try store.create(makeDraft(name: "   "))) { error in
            guard let nameError = error as? DeckNameError, case .empty = nameError else {
                XCTFail("Expected DeckNameError.empty, got \(error)")
                return
            }
        }

        let after = try store.fetchAll()
        XCTAssertEqual(sorted(after).map(\.id), sorted(before).map(\.id))
    }

    func test_create_reservedName_throwsReserved() throws {
        let store = CoreDataDeckStore(context: context, clock: { Date(timeIntervalSince1970: 1_000) })
        let before = try store.fetchAll()

        XCTAssertThrowsError(try store.create(makeDraft(name: "All Cards"))) { error in
            guard let nameError = error as? DeckNameError, case .reserved = nameError else {
                XCTFail("Expected DeckNameError.reserved, got \(error)")
                return
            }
        }

        let after = try store.fetchAll()
        XCTAssertEqual(sorted(after).map(\.id), sorted(before).map(\.id))
    }

    func test_create_duplicateName_throwsDuplicate() throws {
        let store = CoreDataDeckStore(context: context, clock: { Date(timeIntervalSince1970: 1_000) })
        _ = try store.create(makeDraft(name: "Japanese"))
        let before = try store.fetchAll()

        XCTAssertThrowsError(try store.create(makeDraft(name: "Japanese"))) { error in
            guard let nameError = error as? DeckNameError, case .duplicate = nameError else {
                XCTFail("Expected DeckNameError.duplicate, got \(error)")
                return
            }
        }

        let after = try store.fetchAll()
        XCTAssertEqual(after.count, 1)
        XCTAssertEqual(sorted(after).map(\.id), sorted(before).map(\.id))
    }

    // MARK: - B6: Update round-trip
    // Requirements: 3.2, 3.6, 6.5, 6.7

    func test_update_validDraft_preservesIdAndCreatedAt_setsUpdatedAt() throws {
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        let (clock, setClock) = makeMutableClock(initial: t1)
        let store = CoreDataDeckStore(context: context, clock: clock)

        let original = try store.create(makeDraft(name: "Japanese", front: .english, back: .japanese))
        XCTAssertEqual(original.createdAt, t1)
        XCTAssertEqual(original.updatedAt, t1)

        setClock(t2)
        let updated = try store.update(
            id: original.id,
            with: makeDraft(name: "日本語", front: .english, back: .japanese)
        )

        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.createdAt, t1, "createdAt must be preserved across updates")
        XCTAssertEqual(updated.updatedAt, t2, "updatedAt must be set to the clock's current value")
        XCTAssertEqual(updated.name, "日本語")
        XCTAssertEqual(updated.frontLanguage, .english)
        XCTAssertEqual(updated.backLanguage, .japanese)

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, original.id)
        XCTAssertEqual(all.first?.name, "日本語")
        XCTAssertEqual(all.first?.createdAt, t1)
        XCTAssertEqual(all.first?.updatedAt, t2)
    }

    // MARK: - B1 / B2 / B3: Update validation parity (incl. self-exclusion)
    // Requirements: 3.4, 3.5, 5.2, 5.3, 6.2, 6.3

    func test_update_emptyName_throwsEmpty() throws {
        let store = CoreDataDeckStore(context: context, clock: { Date(timeIntervalSince1970: 1_000) })
        let seeded = try store.create(makeDraft(name: "Japanese"))
        let before = try store.fetchAll()

        XCTAssertThrowsError(try store.update(id: seeded.id, with: makeDraft(name: "   "))) { error in
            guard let nameError = error as? DeckNameError, case .empty = nameError else {
                XCTFail("Expected DeckNameError.empty, got \(error)")
                return
            }
        }

        let after = try store.fetchAll()
        XCTAssertEqual(sorted(after), sorted(before), "Failed update must not mutate the store")
    }

    func test_update_reservedName_throwsReserved() throws {
        let store = CoreDataDeckStore(context: context, clock: { Date(timeIntervalSince1970: 1_000) })
        let seeded = try store.create(makeDraft(name: "Japanese"))
        let before = try store.fetchAll()

        XCTAssertThrowsError(try store.update(id: seeded.id, with: makeDraft(name: "All Cards"))) { error in
            guard let nameError = error as? DeckNameError, case .reserved = nameError else {
                XCTFail("Expected DeckNameError.reserved, got \(error)")
                return
            }
        }

        let after = try store.fetchAll()
        XCTAssertEqual(sorted(after), sorted(before), "Failed update must not mutate the store")
    }

    func test_update_duplicateOfOther_throwsDuplicate() throws {
        let store = CoreDataDeckStore(context: context, clock: { Date(timeIntervalSince1970: 1_000) })
        _ = try store.create(makeDraft(name: "Japanese"))
        let korean = try store.create(makeDraft(name: "Korean"))
        let before = try store.fetchAll()

        XCTAssertThrowsError(try store.update(id: korean.id, with: makeDraft(name: "Japanese"))) { error in
            guard let nameError = error as? DeckNameError, case .duplicate = nameError else {
                XCTFail("Expected DeckNameError.duplicate, got \(error)")
                return
            }
        }

        let after = try store.fetchAll()
        XCTAssertEqual(sorted(after), sorted(before), "Failed update must not mutate the store")
    }

    func test_update_sameNameAsSelf_succeeds() throws {
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        let (clock, setClock) = makeMutableClock(initial: t1)
        let store = CoreDataDeckStore(context: context, clock: clock)

        let seeded = try store.create(makeDraft(name: "Japanese", front: .english, back: .japanese))

        setClock(t2)
        let updated = try store.update(
            id: seeded.id,
            with: makeDraft(name: "Japanese", front: .japanese, back: .english)
        )

        XCTAssertEqual(updated.id, seeded.id)
        XCTAssertEqual(updated.name, "Japanese")
        XCTAssertEqual(updated.frontLanguage, .japanese)
        XCTAssertEqual(updated.backLanguage, .english)
        XCTAssertEqual(updated.createdAt, t1)
        XCTAssertEqual(updated.updatedAt, t2)
    }

    // MARK: - B11: Delete detaches cards without deleting them
    // Requirements: 4.2, 4.3, 6.6

    func test_delete_detachesCardsWithoutDeletingThem() throws {
        // Seed two Deck objects and two Card objects directly via NSManagedObject
        // inserts, bypassing CoreDataDeckStore so we can wire the cards relationship
        // before the store is constructed.
        let deckDId = UUID()
        let deckEId = UUID()
        let cardC1Id = UUID()
        let cardC2Id = UUID()

        let t0 = Date(timeIntervalSince1970: 500)

        let deckD = NSEntityDescription.insertNewObject(forEntityName: "Deck", into: context)
        deckD.setValue(deckDId, forKey: "id")
        deckD.setValue("Japanese", forKey: "name")
        deckD.setValue(Language.english.rawValue, forKey: "frontLanguageRaw")
        deckD.setValue(Language.japanese.rawValue, forKey: "backLanguageRaw")
        deckD.setValue(t0, forKey: "createdAt")
        deckD.setValue(t0, forKey: "updatedAt")

        let deckE = NSEntityDescription.insertNewObject(forEntityName: "Deck", into: context)
        deckE.setValue(deckEId, forKey: "id")
        deckE.setValue("Korean", forKey: "name")
        deckE.setValue(Language.english.rawValue, forKey: "frontLanguageRaw")
        deckE.setValue(Language.other.rawValue, forKey: "backLanguageRaw")
        deckE.setValue(t0, forKey: "createdAt")
        deckE.setValue(t0, forKey: "updatedAt")

        let cardC1 = NSEntityDescription.insertNewObject(forEntityName: "Card", into: context)
        cardC1.setValue(cardC1Id, forKey: "id")
        cardC1.setValue("front1", forKey: "frontText")
        cardC1.setValue("back1", forKey: "backText")
        cardC1.setValue(t0, forKey: "createdAt")
        cardC1.setValue(Set<NSManagedObject>([deckD]), forKey: "decks")

        let cardC2 = NSEntityDescription.insertNewObject(forEntityName: "Card", into: context)
        cardC2.setValue(cardC2Id, forKey: "id")
        cardC2.setValue("front2", forKey: "frontText")
        cardC2.setValue("back2", forKey: "backText")
        cardC2.setValue(t0, forKey: "createdAt")
        cardC2.setValue(Set<NSManagedObject>([deckD, deckE]), forKey: "decks")

        try context.save()

        // Act: delete deck D via the store.
        let store = CoreDataDeckStore(context: context, clock: { Date(timeIntervalSince1970: 1_000) })
        try store.delete(id: deckDId)

        // Assert: D is gone from fetchAll; E remains with original attributes.
        let remainingDecks = try store.fetchAll()
        XCTAssertEqual(remainingDecks.count, 1)
        XCTAssertFalse(remainingDecks.contains(where: { $0.id == deckDId }))

        let remainingE = remainingDecks.first(where: { $0.id == deckEId })
        XCTAssertNotNil(remainingE)
        XCTAssertEqual(remainingE?.name, "Korean")
        XCTAssertEqual(remainingE?.frontLanguage, .english)
        XCTAssertEqual(remainingE?.backLanguage, .other)
        XCTAssertEqual(remainingE?.createdAt, t0)
        XCTAssertEqual(remainingE?.updatedAt, t0)

        // Assert: both cards still exist in the context.
        let cardFetch = NSFetchRequest<NSManagedObject>(entityName: "Card")
        let cards = try context.fetch(cardFetch)
        XCTAssertEqual(cards.count, 2, "Cards must not be deleted when a deck is deleted")

        let cardIds = Set(cards.compactMap { $0.value(forKey: "id") as? UUID })
        XCTAssertEqual(cardIds, [cardC1Id, cardC2Id])

        // Assert: C1.decks is empty (D was its only deck).
        let fetchedC1 = try XCTUnwrap(cards.first(where: { ($0.value(forKey: "id") as? UUID) == cardC1Id }))
        let c1Decks = fetchedC1.value(forKey: "decks") as? Set<NSManagedObject> ?? []
        let c1DeckIds = Set(c1Decks.compactMap { $0.value(forKey: "id") as? UUID })
        XCTAssertFalse(c1DeckIds.contains(deckDId), "C1 must be detached from deleted deck D")
        XCTAssertTrue(c1DeckIds.isEmpty, "C1 had only D; after delete its deck set must be empty")

        // Assert: C2.decks contains exactly E.
        let fetchedC2 = try XCTUnwrap(cards.first(where: { ($0.value(forKey: "id") as? UUID) == cardC2Id }))
        let c2Decks = fetchedC2.value(forKey: "decks") as? Set<NSManagedObject> ?? []
        let c2DeckIds = Set(c2Decks.compactMap { $0.value(forKey: "id") as? UUID })
        XCTAssertEqual(c2DeckIds, [deckEId], "C2 must remain attached only to deck E after D is deleted")
    }
}
