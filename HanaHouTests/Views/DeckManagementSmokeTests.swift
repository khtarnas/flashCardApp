//
//  DeckManagementSmokeTests.swift
//  HanaHouTests
//
//  Feature: deck-management + card-management
//  Non-algorithmic smoke tests for the view layer and view-model/store boundary:
//  NavigationStack root type, editor bindable fields, editor pre-population in edit mode,
//  rename/delete on .allCards throw .notAllowed, DeckListItem.deck exposes name/front/back,
//  a Card associated with two Decks is reachable from both after one deck is deleted,
//  card-management additions: card editor bindable fields, card editor edit-mode pre-population,
//  CardRowItem field exposure, and the deck-management route change
//  (tapping a user-deck row routes to .cardList instead of .editDeck).
//
//  Validates requirements: 1.1, 1.2, 2.1, 2.2, 3.1, 4.3, 4.4, 5.3, 5.7, 6.6, 7.1, 8.1, 8.3, 8.4
//

import XCTest
import CoreData
import SwiftUI
@testable import HanaHou

@MainActor
final class DeckManagementSmokeTests: XCTestCase {

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

    // MARK: - NavigationStack root (Req 7.1)

    func test_deckManagementRootView_canBeInstantiatedWithStore() {
        let deckStore = InMemoryDeckStore()
        let cardStore = InMemoryCardStore()
        let deckStrategy = CreationDateAscendingOrdering()
        let cardStrategy = CardCreationDateAscendingOrdering()

        let view = DeckManagementRootView(
            deckStore: deckStore,
            cardStore: cardStore,
            deckStrategy: deckStrategy,
            cardStrategy: cardStrategy
        )

        // Forcing body evaluation confirms the NavigationStack-rooted view tree
        // compiles and its destinations are reachable. We avoid asserting on
        // SwiftUI's mangled generic types directly because they're fragile.
        _ = view.body
    }

    // MARK: - Editor bindable fields (Req 2.1, 3.1)

    func test_deckEditorViewModel_exposesBindableFields() {
        let store = InMemoryDeckStore()
        let vm = DeckEditorViewModel(mode: .create, store: store)

        vm.name = "Hello"
        vm.frontLanguage = .mandarin
        vm.backLanguage = .hawaiian

        XCTAssertEqual(vm.name, "Hello")
        XCTAssertEqual(vm.frontLanguage, .mandarin)
        XCTAssertEqual(vm.backLanguage, .hawaiian)
    }

    // MARK: - Editor edit-mode pre-population (Req 3.1)

    func test_deckEditorViewModel_editMode_prepopulatesFromSnapshot() throws {
        let store = InMemoryDeckStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let seeded = try store.create(
            DeckDraft(name: "Japanese", frontLanguage: .english, backLanguage: .japanese)
        )

        let vm = DeckEditorViewModel(mode: .edit(seeded), store: store)

        XCTAssertEqual(vm.name, "Japanese")
        XCTAssertEqual(vm.frontLanguage, .english)
        XCTAssertEqual(vm.backLanguage, .japanese)
    }

    // MARK: - Rename/delete on .allCards throw .notAllowed (Req 4.4, 8.3, 8.4)

    func test_deckListViewModel_renameAllCards_throwsNotAllowed() {
        let store = InMemoryDeckStore()
        let vm = DeckListViewModel(store: store, strategy: CreationDateAscendingOrdering())

        XCTAssertThrowsError(try vm.rename(item: .allCards, to: "Anything")) { error in
            guard case AllCardsActionError.notAllowed = error else {
                XCTFail("Expected AllCardsActionError.notAllowed, got \(error)")
                return
            }
        }
    }

    func test_deckListViewModel_deleteAllCards_throwsNotAllowed() {
        let store = InMemoryDeckStore()
        let vm = DeckListViewModel(store: store, strategy: CreationDateAscendingOrdering())

        XCTAssertThrowsError(try vm.delete(item: .allCards)) { error in
            guard case AllCardsActionError.notAllowed = error else {
                XCTFail("Expected AllCardsActionError.notAllowed, got \(error)")
                return
            }
        }
    }

    // MARK: - DeckListItem.deck exposes name and languages (Req 1.2)

    func test_deckListItem_deckCase_exposesNameAndLanguages() {
        let snapshot = DeckSnapshot(
            id: UUID(),
            name: "Japanese",
            frontLanguage: .english,
            backLanguage: .japanese,
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let item = DeckListItem.deck(snapshot)

        guard case .deck(let unwrapped) = item else {
            XCTFail("Expected .deck case")
            return
        }
        XCTAssertEqual(unwrapped.name, "Japanese")
        XCTAssertEqual(unwrapped.frontLanguage, .english)
        XCTAssertEqual(unwrapped.backLanguage, .japanese)
    }

    // MARK: - Card reachable from two decks after one is deleted (Req 6.6, 4.3)
    // Mirrors B11 from CoreDataDeckStoreTests, re-asserted at the view-model/store
    // boundary per tasks.md Notes ("B11 overlap is intentional").

    func test_cardReachableFromTwoDecks_persistsAfterOneDeckDeleted() throws {
        let container = Self.makeInMemoryContainer()
        let context = container.viewContext

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

        // Delete deck D via the store (same path the view model uses).
        let store = CoreDataDeckStore(
            context: context,
            clock: { Date(timeIntervalSince1970: 1_000) }
        )
        try store.delete(id: deckDId)

        // C2 still exists and is reachable only from E.
        let cardFetch = NSFetchRequest<NSManagedObject>(entityName: "Card")
        let cards = try context.fetch(cardFetch)
        XCTAssertEqual(cards.count, 2, "Cards must not be deleted when a deck is deleted")

        let fetchedC2 = try XCTUnwrap(
            cards.first(where: { ($0.value(forKey: "id") as? UUID) == cardC2Id })
        )
        let c2Decks = fetchedC2.value(forKey: "decks") as? Set<NSManagedObject> ?? []
        let c2DeckIds = Set(c2Decks.compactMap { $0.value(forKey: "id") as? UUID })
        XCTAssertEqual(c2DeckIds, [deckEId], "C2 must remain attached only to deck E")

        // C1 still exists but is no longer attached to any deck.
        let fetchedC1 = try XCTUnwrap(
            cards.first(where: { ($0.value(forKey: "id") as? UUID) == cardC1Id })
        )
        let c1Decks = fetchedC1.value(forKey: "decks") as? Set<NSManagedObject> ?? []
        XCTAssertTrue(c1Decks.isEmpty, "C1 had only D; after delete its deck set must be empty")
    }

    // MARK: - Card editor bindable fields (Req 1.1, 3.1)

    func test_cardEditorViewModel_exposesBindableFields() {
        let store = InMemoryCardStore()
        let vm = CardEditorViewModel(mode: .create(deckId: UUID()), store: store)

        vm.frontText = "hello"
        vm.backText = "world"

        XCTAssertEqual(vm.frontText, "hello")
        XCTAssertEqual(vm.backText, "world")
    }

    // MARK: - Card editor edit-mode pre-population (Req 3.1)

    func test_cardEditorViewModel_editMode_prepopulatesFromSnapshot() throws {
        let store = InMemoryCardStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let deckId = UUID()
        let seeded = try store.create(frontText: "hi", backText: "bye", deckIds: [deckId])

        let vm = CardEditorViewModel(mode: .edit(seeded), store: store)

        XCTAssertEqual(vm.frontText, "hi")
        XCTAssertEqual(vm.backText, "bye")
    }

    // MARK: - CardRowItem exposes front/back/isOrphan (Req 2.2, 5.3)

    func test_cardRowItem_exposesFrontBackAndIsOrphan() {
        let nonOrphan = CardRowItem(
            id: UUID(),
            frontText: "front",
            backText: "back",
            isOrphan: false
        )
        let orphan = CardRowItem(
            id: UUID(),
            frontText: "front",
            backText: "back",
            isOrphan: true
        )

        XCTAssertEqual(nonOrphan.frontText, "front")
        XCTAssertEqual(nonOrphan.backText, "back")
        XCTAssertFalse(nonOrphan.isOrphan)
        XCTAssertTrue(orphan.isOrphan)
    }

    // MARK: - Deck-row tap routes to .cardList (route change — Req 2.1, 5.1, 5.7, 8.1)
    //
    // The design-approved change: tapping a user-deck row now pushes
    // `.cardList(deck)` rather than `.editDeck(deck)`. We can't assert on
    // SwiftUI's button handler directly, but we can assert on the route
    // enum's shape to guard against an accidental regression.

    func test_deckManagementRoute_cardListCaseExists() {
        let snapshot = DeckSnapshot(
            id: UUID(),
            name: "Japanese",
            frontLanguage: .english,
            backLanguage: .japanese,
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )

        let route: DeckManagementRoute = .cardList(snapshot)

        guard case .cardList(let decoded) = route else {
            XCTFail("Expected .cardList case to exist on DeckManagementRoute")
            return
        }
        XCTAssertEqual(decoded.id, snapshot.id)
    }

    func test_deckManagementRoute_editCardAndCreateCardCasesExist() {
        let cardSnapshot = CardSnapshot(
            id: UUID(),
            frontText: "front",
            backText: "back",
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_000),
            deckIds: []
        )
        let deckId = UUID()

        let editRoute: DeckManagementRoute = .editCard(cardSnapshot)
        let createRoute: DeckManagementRoute = .createCard(deckId: deckId)

        guard case .editCard(let decoded) = editRoute else {
            XCTFail("Expected .editCard case on DeckManagementRoute")
            return
        }
        XCTAssertEqual(decoded.id, cardSnapshot.id)

        guard case .createCard(let decodedDeckId) = createRoute else {
            XCTFail("Expected .createCard case on DeckManagementRoute")
            return
        }
        XCTAssertEqual(decodedDeckId, deckId)
    }
}
