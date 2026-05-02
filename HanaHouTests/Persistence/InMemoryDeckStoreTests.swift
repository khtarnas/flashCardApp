//
//  InMemoryDeckStoreTests.swift
//  HanaHouTests
//
//  Feature: deck-management
//  Covers behaviors: B1 (empty), B2 (reserved), B3 (duplicate w/ edit self-exclusion), B5 (create round-trip), B6 (edit round-trip), change-publisher emission
//  Validates requirements: 1.8, 2.3, 2.7, 2.8, 3.2, 3.6, 5.1, 5.2, 5.3, 5.4, 6.2, 6.3, 6.4, 6.5, 6.7
//

import XCTest
import Combine
@testable import HanaHou

final class InMemoryDeckStoreTests: XCTestCase {

    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    // MARK: - Helpers

    private func makeDraft(
        name: String = "Japanese",
        front: Language = .english,
        back: Language = .japanese
    ) -> DeckDraft {
        DeckDraft(name: name, frontLanguage: front, backLanguage: back)
    }

    /// Returns a mutable clock closure plus a setter, so tests can advance time.
    private func makeMutableClock(initial: Date) -> (clock: () -> Date, set: (Date) -> Void) {
        // Use a class wrapper so the closure captures a mutable reference.
        final class Box { var date: Date; init(_ d: Date) { self.date = d } }
        let box = Box(initial)
        return ({ box.date }, { box.date = $0 })
    }

    /// Sort decks deterministically by (createdAt, id) for order-insensitive assertions.
    private func sorted(_ decks: [DeckSnapshot]) -> [DeckSnapshot] {
        decks.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    }

    /// Waits briefly so a PassthroughSubject has a chance to emit, then returns.
    private func waitBriefly(_ timeout: TimeInterval = 0.05) {
        let exp = expectation(description: "brief wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    // MARK: - B5: Create round-trip
    // Requirements: 2.3, 2.7, 2.8, 6.4

    func test_create_validDraft_returnsSnapshotAndPersists() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let store = InMemoryDeckStore(clock: { t })
        let draft = makeDraft()

        let snapshot = try store.create(draft)

        XCTAssertEqual(snapshot.name, draft.name)
        XCTAssertEqual(snapshot.frontLanguage, draft.frontLanguage)
        XCTAssertEqual(snapshot.backLanguage, draft.backLanguage)

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, snapshot.id)
        XCTAssertEqual(all.first?.name, draft.name)
    }

    func test_create_setsCreatedAtAndUpdatedAtFromInjectedClock() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let store = InMemoryDeckStore(clock: { t })

        let snapshot = try store.create(makeDraft())

        XCTAssertEqual(snapshot.createdAt, t)
        XCTAssertEqual(snapshot.updatedAt, t)
        XCTAssertEqual(snapshot.createdAt, snapshot.updatedAt)
    }

    // MARK: - B1 / B2 / B3: Create validation
    // Requirements: 5.1, 5.3, 5.2, 5.4, 6.2, 6.3

    func test_create_emptyName_throwsEmpty() throws {
        let store = InMemoryDeckStore(clock: { Date(timeIntervalSince1970: 1_000) })
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
        let store = InMemoryDeckStore(clock: { Date(timeIntervalSince1970: 1_000) })
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
        let store = InMemoryDeckStore(clock: { Date(timeIntervalSince1970: 1_000) })
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
        let store = InMemoryDeckStore(clock: clock)

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

    // MARK: - B1 / B2 / B3: Update validation (with edit self-exclusion)
    // Requirements: 5.1, 5.2, 5.3, 5.4, 6.2, 6.3

    func test_update_emptyName_throwsEmpty() throws {
        let store = InMemoryDeckStore(clock: { Date(timeIntervalSince1970: 1_000) })
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
        let store = InMemoryDeckStore(clock: { Date(timeIntervalSince1970: 1_000) })
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
        let store = InMemoryDeckStore(clock: { Date(timeIntervalSince1970: 1_000) })
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
        let store = InMemoryDeckStore(clock: clock)

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

    // MARK: - Delete

    func test_delete_existingDeck_removesFromFetchAll() throws {
        let store = InMemoryDeckStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let japanese = try store.create(makeDraft(name: "Japanese"))
        let korean = try store.create(makeDraft(name: "Korean"))

        try store.delete(id: japanese.id)

        let after = try store.fetchAll()
        XCTAssertEqual(after.count, 1)
        XCTAssertEqual(after.first?.id, korean.id)
        XCTAssertEqual(after.first?.name, "Korean")
    }

    func test_delete_nonExistentId_isSilentNoOp_andDoesNotEmit() throws {
        let store = InMemoryDeckStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let seeded = try store.create(makeDraft(name: "Japanese"))
        let before = try store.fetchAll()

        var count = 0
        store.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        // Deleting an id that doesn't exist must not throw, must not mutate
        // the store, and must not emit on `changes`. Idempotent delete per
        // DeckStore contract.
        XCTAssertNoThrow(try store.delete(id: UUID()))

        waitBriefly()

        let after = try store.fetchAll()
        XCTAssertEqual(
            sorted(after).map(\.id),
            sorted(before).map(\.id),
            "Deleting a non-existent id must leave the store unchanged"
        )
        XCTAssertEqual(
            after.first?.id,
            seeded.id,
            "The existing deck must still be present"
        )
        XCTAssertEqual(
            count,
            0,
            "Change publisher must not emit for a no-op delete"
        )
    }

    // MARK: - Change-publisher emission
    // Requirements: 1.8

    func test_changes_emitsOnCreate() throws {
        let store = InMemoryDeckStore(clock: { Date(timeIntervalSince1970: 1_000) })
        var count = 0
        store.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        _ = try store.create(makeDraft(name: "Japanese"))

        waitBriefly()
        XCTAssertEqual(count, 1)
    }

    func test_changes_emitsOnUpdate() throws {
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        let (clock, setClock) = makeMutableClock(initial: t1)
        let store = InMemoryDeckStore(clock: clock)
        let seeded = try store.create(makeDraft(name: "Japanese"))

        var count = 0
        store.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        setClock(t2)
        _ = try store.update(id: seeded.id, with: makeDraft(name: "日本語"))

        waitBriefly()
        XCTAssertEqual(count, 1)
    }

    func test_changes_emitsOnDelete() throws {
        let store = InMemoryDeckStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let seeded = try store.create(makeDraft(name: "Japanese"))

        var count = 0
        store.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        try store.delete(id: seeded.id)

        waitBriefly()
        XCTAssertEqual(count, 1)
    }

    func test_changes_doesNotEmitOnFailedCreate() {
        let store = InMemoryDeckStore(clock: { Date(timeIntervalSince1970: 1_000) })

        var count = 0
        store.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        XCTAssertThrowsError(try store.create(makeDraft(name: "   ")))

        waitBriefly()
        XCTAssertEqual(count, 0, "Change publisher must not emit when a mutation fails validation")
    }

    func test_changes_doesNotEmitOnFailedUpdate() throws {
        let store = InMemoryDeckStore(clock: { Date(timeIntervalSince1970: 1_000) })
        let seeded = try store.create(makeDraft(name: "Japanese"))

        var count = 0
        store.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        XCTAssertThrowsError(try store.update(id: seeded.id, with: makeDraft(name: "All Cards")))

        waitBriefly()
        XCTAssertEqual(count, 0, "Change publisher must not emit when a mutation fails validation")
    }
}
