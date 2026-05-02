//
//  DeckListViewModelTests.swift
//  HanaHouTests
//
//  Feature: deck-management
//  Covers behaviors: B8 (exactly one .allCards at index 0), B9 (user-deck subsequence = strategy output), B10 (mutations propagate), + AllCardsActionError defense-in-depth
//  Validates requirements: 1.1, 1.3, 1.4, 1.5, 1.8, 4.4, 8.1, 8.3, 8.4
//

import XCTest
import Combine
@testable import HanaHou

private struct ReverseOrderingStub: DeckOrderingStrategy {
    func order(_ decks: [DeckSnapshot]) -> [DeckSnapshot] { decks.reversed() }
}

@MainActor
final class DeckListViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeDraft(
        name: String = "Japanese",
        front: Language = .english,
        back: Language = .japanese
    ) -> DeckDraft {
        DeckDraft(name: name, frontLanguage: front, backLanguage: back)
    }

    /// Extracts user-deck ids from a `[DeckListItem]`, skipping `.allCards` entries.
    private func deckIds(_ items: [DeckListItem]) -> [UUID] {
        items.compactMap {
            if case .deck(let s) = $0 { return s.id }
            return nil
        }
    }

    /// Advances the runloop briefly so Combine emissions have time to propagate through Main.
    private func waitBriefly(_ timeout: TimeInterval = 0.05) {
        let exp = expectation(description: "brief wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// Returns a mutable clock closure plus a setter so tests can control `createdAt`.
    private func makeMutableClock(initial: Date) -> (clock: () -> Date, set: (Date) -> Void) {
        final class Box { var date: Date; init(_ d: Date) { self.date = d } }
        let box = Box(initial)
        return ({ box.date }, { box.date = $0 })
    }

    // MARK: - B8: exactly one .allCards at index 0, strategy-independent
    // Requirements: 1.3, 1.4, 8.1

    func test_items_startsWithAllCardsAtIndex0_emptyStore() {
        let store = InMemoryDeckStore(clock: { Date(timeIntervalSince1970: 1_000) })

        let vm = DeckListViewModel(store: store, strategy: CreationDateAscendingOrdering())

        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(vm.items.first?.id, .allCards)
    }

    func test_items_hasExactlyOneAllCardsAcrossStrategies() throws {
        let (clock, setClock) = makeMutableClock(initial: Date(timeIntervalSince1970: 1_000))
        let store = InMemoryDeckStore(clock: clock)

        _ = try store.create(makeDraft(name: "Japanese"))
        setClock(Date(timeIntervalSince1970: 2_000))
        _ = try store.create(makeDraft(name: "Korean"))
        setClock(Date(timeIntervalSince1970: 3_000))
        _ = try store.create(makeDraft(name: "Hawaiian"))

        let vmP0 = DeckListViewModel(store: store, strategy: CreationDateAscendingOrdering())
        XCTAssertEqual(vmP0.items.first?.id, .allCards)
        XCTAssertEqual(vmP0.items.filter { $0.id == .allCards }.count, 1)

        let vmReverse = DeckListViewModel(store: store, strategy: ReverseOrderingStub())
        XCTAssertEqual(vmReverse.items.first?.id, .allCards)
        XCTAssertEqual(vmReverse.items.filter { $0.id == .allCards }.count, 1)
    }

    // MARK: - B9: user-deck subsequence equals strategy.order(storedDecks)
    // Requirements: 1.1, 1.5

    func test_userDeckSubsequence_usingP0Strategy_matchesStrategyOutput() throws {
        let (clock, setClock) = makeMutableClock(initial: Date(timeIntervalSince1970: 2_000))
        let store = InMemoryDeckStore(clock: clock)

        _ = try store.create(makeDraft(name: "Japanese"))
        setClock(Date(timeIntervalSince1970: 1_000))
        _ = try store.create(makeDraft(name: "Korean"))
        setClock(Date(timeIntervalSince1970: 3_000))
        _ = try store.create(makeDraft(name: "Hawaiian"))

        let strategy = CreationDateAscendingOrdering()
        let vm = DeckListViewModel(store: store, strategy: strategy)

        let tail = Array(vm.items.dropFirst())
        let stored = try store.fetchAll()
        let expectedIds = strategy.order(stored).map(\.id)
        XCTAssertEqual(deckIds(tail), expectedIds)
    }

    func test_userDeckSubsequence_usingReverseStub_matchesStrategyOutput() throws {
        let (clock, setClock) = makeMutableClock(initial: Date(timeIntervalSince1970: 1_000))
        let store = InMemoryDeckStore(clock: clock)

        _ = try store.create(makeDraft(name: "Japanese"))
        setClock(Date(timeIntervalSince1970: 2_000))
        _ = try store.create(makeDraft(name: "Korean"))
        setClock(Date(timeIntervalSince1970: 3_000))
        _ = try store.create(makeDraft(name: "Hawaiian"))

        let strategy = ReverseOrderingStub()
        let vm = DeckListViewModel(store: store, strategy: strategy)

        let tail = Array(vm.items.dropFirst())
        let stored = try store.fetchAll()
        let expectedIds = strategy.order(stored).map(\.id)
        XCTAssertEqual(deckIds(tail), expectedIds)
    }

    // MARK: - B10: store mutations propagate to items
    // Requirements: 1.8

    func test_items_updatesOnCreate() throws {
        let store = InMemoryDeckStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let vm = DeckListViewModel(store: store, strategy: CreationDateAscendingOrdering())

        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(vm.items.first?.id, .allCards)

        let created = try store.create(makeDraft(name: "Japanese"))
        waitBriefly()

        XCTAssertEqual(vm.items.count, 2)
        XCTAssertEqual(vm.items.first?.id, .allCards)
        XCTAssertEqual(deckIds(vm.items), [created.id])
    }

    func test_items_updatesOnUpdate() throws {
        let (clock, setClock) = makeMutableClock(initial: Date(timeIntervalSince1970: 1_000))
        let store = InMemoryDeckStore(clock: clock)
        let seeded = try store.create(makeDraft(name: "Japanese"))

        let vm = DeckListViewModel(store: store, strategy: CreationDateAscendingOrdering())
        waitBriefly()
        XCTAssertEqual(deckIds(vm.items), [seeded.id])

        setClock(Date(timeIntervalSince1970: 2_000))
        _ = try store.update(
            id: seeded.id,
            with: makeDraft(name: "日本語", front: .english, back: .japanese)
        )
        waitBriefly()

        let tail = Array(vm.items.dropFirst())
        guard case .deck(let snapshot) = tail.first else {
            XCTFail("Expected a .deck item after update")
            return
        }
        XCTAssertEqual(snapshot.id, seeded.id)
        XCTAssertEqual(snapshot.name, "日本語")
    }

    func test_items_updatesOnDelete() throws {
        let (clock, setClock) = makeMutableClock(initial: Date(timeIntervalSince1970: 1_000))
        let store = InMemoryDeckStore(clock: clock)
        let japanese = try store.create(makeDraft(name: "Japanese"))
        setClock(Date(timeIntervalSince1970: 2_000))
        let korean = try store.create(makeDraft(name: "Korean"))

        let vm = DeckListViewModel(store: store, strategy: CreationDateAscendingOrdering())
        waitBriefly()
        XCTAssertEqual(Set(deckIds(vm.items)), Set([japanese.id, korean.id]))

        try store.delete(id: japanese.id)
        waitBriefly()

        XCTAssertEqual(deckIds(vm.items), [korean.id])
        XCTAssertFalse(deckIds(vm.items).contains(japanese.id))
    }

    // MARK: - AllCardsActionError defense-in-depth
    // Requirements: 4.4, 8.3, 8.4

    func test_rename_allCardsItem_throwsNotAllowed() {
        let store = InMemoryDeckStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let vm = DeckListViewModel(store: store, strategy: CreationDateAscendingOrdering())

        XCTAssertThrowsError(try vm.rename(item: .allCards, to: "anything")) { error in
            XCTAssertEqual(error as? AllCardsActionError, .notAllowed)
        }
    }

    func test_delete_allCardsItem_throwsNotAllowed() {
        let store = InMemoryDeckStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let vm = DeckListViewModel(store: store, strategy: CreationDateAscendingOrdering())

        XCTAssertThrowsError(try vm.delete(item: .allCards)) { error in
            XCTAssertEqual(error as? AllCardsActionError, .notAllowed)
        }
    }

    func test_rename_deckItem_dispatchesToStore() throws {
        let store = InMemoryDeckStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let seeded = try store.create(makeDraft(name: "Japanese"))
        let vm = DeckListViewModel(store: store, strategy: CreationDateAscendingOrdering())

        try vm.rename(item: .deck(seeded), to: "日本語")
        waitBriefly()

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, seeded.id)
        XCTAssertEqual(all.first?.name, "日本語")
    }

    func test_delete_deckItem_dispatchesToStore() throws {
        let store = InMemoryDeckStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let seeded = try store.create(makeDraft(name: "Japanese"))
        let vm = DeckListViewModel(store: store, strategy: CreationDateAscendingOrdering())

        try vm.delete(item: .deck(seeded))
        waitBriefly()

        let all = try store.fetchAll()
        XCTAssertTrue(all.isEmpty, "Delete must remove the target deck from the store")
    }
}
