//
//  CardEditorViewModelTests.swift
//  HanaHouTests
//
//  Feature: card-management
//  Covers behaviors: C1, C2, C3, C4, C7
//  Validates requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2, 4.3, 4.4, 6.1, 6.3, 6.4
//

import XCTest
import Combine
@testable import HanaHou

@MainActor
final class CardEditorViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeStore(
        clock: @escaping () -> Date = { Date(timeIntervalSince1970: 1_000) }
    ) -> InMemoryCardStore {
        InMemoryCardStore(clock: clock)
    }

    /// Returns a mutable clock closure plus a setter, so tests can advance time
    /// between create and update to exercise `updatedAt` semantics (C4).
    private func makeMutableClock(initial: Date) -> (clock: () -> Date, set: (Date) -> Void) {
        final class Box { var date: Date; init(_ d: Date) { self.date = d } }
        let box = Box(initial)
        return ({ box.date }, { box.date = $0 })
    }

    /// Advances the runloop briefly so Combine emissions have time to propagate.
    private func waitBriefly(_ timeout: TimeInterval = 0.05) {
        let exp = expectation(description: "brief wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    // MARK: - Initialization

    func test_createMode_initializesWithEmptyTextAndNoErrors() {
        let store = makeStore()
        let deckId = UUID()

        let vm = CardEditorViewModel(mode: .create(deckId: deckId), store: store)

        XCTAssertEqual(vm.frontText, "")
        XCTAssertEqual(vm.backText, "")
        XCTAssertNil(vm.frontError)
        XCTAssertNil(vm.backError)
    }

    func test_editMode_prePopulatesFromSnapshot() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let store = makeStore(clock: { t })
        let deckId = UUID()
        let seeded = try store.create(frontText: "hi", backText: "hello", deckIds: [deckId])

        let vm = CardEditorViewModel(mode: .edit(seeded), store: store)

        XCTAssertEqual(vm.frontText, seeded.frontText)
        XCTAssertEqual(vm.backText, seeded.backText)
        XCTAssertNil(vm.frontError)
        XCTAssertNil(vm.backError)
    }

    // MARK: - C1: Empty front (validate + submit gating)
    // Requirements: 1.3, 3.3

    func test_validate_emptyFront_setsFrontErrorToMissingFront() {
        let store = makeStore()
        let vm = CardEditorViewModel(mode: .create(deckId: UUID()), store: store)

        vm.frontText = ""
        vm.backText = "hello"
        vm.validate()

        XCTAssertEqual(vm.frontError, .missingFront)
    }

    func test_validate_whitespaceFront_setsFrontErrorToMissingFront() {
        let store = makeStore()
        let vm = CardEditorViewModel(mode: .create(deckId: UUID()), store: store)

        vm.frontText = " \t\n "
        vm.backText = "hello"
        vm.validate()

        XCTAssertEqual(vm.frontError, .missingFront)
    }

    func test_submit_createMode_emptyFront_throwsMissingFront_doesNotPersist_setsError() throws {
        let store = makeStore()
        let deckId = UUID()
        let vm = CardEditorViewModel(mode: .create(deckId: deckId), store: store)

        vm.frontText = ""
        vm.backText = "hello"

        XCTAssertThrowsError(try vm.submit()) { error in
            XCTAssertEqual(error as? CardTextError, .missingFront)
        }
        XCTAssertEqual(vm.frontError, .missingFront)

        let all = try store.fetchAll()
        XCTAssertTrue(all.isEmpty, "Failed submit must not persist anything")
    }

    func test_submit_editMode_emptyFront_throwsMissingFront_doesNotMutate_setsError() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let store = makeStore(clock: { t })
        let deckId = UUID()
        let seeded = try store.create(frontText: "original front", backText: "original back", deckIds: [deckId])
        let vm = CardEditorViewModel(mode: .edit(seeded), store: store)

        vm.frontText = "   "
        vm.backText = "changed back"

        XCTAssertThrowsError(try vm.submit()) { error in
            XCTAssertEqual(error as? CardTextError, .missingFront)
        }
        XCTAssertEqual(vm.frontError, .missingFront)

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.frontText, "original front", "Failed edit must not mutate stored front")
        XCTAssertEqual(all.first?.backText, "original back", "Failed edit must not mutate stored back")
    }

    // MARK: - C2: Empty back (validate + submit gating)
    // Requirements: 1.4, 3.4

    func test_validate_emptyBack_setsBackErrorToMissingBack() {
        let store = makeStore()
        let vm = CardEditorViewModel(mode: .create(deckId: UUID()), store: store)

        vm.frontText = "hi"
        vm.backText = ""
        vm.validate()

        XCTAssertEqual(vm.backError, .missingBack)
    }

    func test_submit_createMode_emptyBack_throwsMissingBack_doesNotPersist_setsError() throws {
        let store = makeStore()
        let vm = CardEditorViewModel(mode: .create(deckId: UUID()), store: store)

        vm.frontText = "hi"
        vm.backText = "\n\t"

        XCTAssertThrowsError(try vm.submit()) { error in
            XCTAssertEqual(error as? CardTextError, .missingBack)
        }
        XCTAssertEqual(vm.backError, .missingBack)

        let all = try store.fetchAll()
        XCTAssertTrue(all.isEmpty, "Failed submit must not persist anything")
    }

    func test_submit_editMode_emptyBack_throwsMissingBack_doesNotMutate_setsError() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let store = makeStore(clock: { t })
        let deckId = UUID()
        let seeded = try store.create(frontText: "original front", backText: "original back", deckIds: [deckId])
        let vm = CardEditorViewModel(mode: .edit(seeded), store: store)

        vm.frontText = "changed front"
        vm.backText = ""

        XCTAssertThrowsError(try vm.submit()) { error in
            XCTAssertEqual(error as? CardTextError, .missingBack)
        }
        XCTAssertEqual(vm.backError, .missingBack)

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.frontText, "original front")
        XCTAssertEqual(all.first?.backText, "original back")
    }

    // MARK: - C1 + C2: Both fields empty surfaces BOTH errors concurrently
    // Requirements: 1.3, 1.4, 3.3, 3.4

    func test_validate_bothFieldsEmpty_setsBothErrorsConcurrently() {
        let store = makeStore()
        let vm = CardEditorViewModel(mode: .create(deckId: UUID()), store: store)

        vm.frontText = ""
        vm.backText = ""
        vm.validate()

        XCTAssertEqual(vm.frontError, .missingFront,
                       "Both-empty must surface frontError on the independent @Published channel")
        XCTAssertEqual(vm.backError, .missingBack,
                       "Both-empty must surface backError on the independent @Published channel")
    }

    // MARK: - Valid input clears errors

    func test_validate_validFront_clearsFrontError() {
        let store = makeStore()
        let vm = CardEditorViewModel(mode: .create(deckId: UUID()), store: store)

        vm.frontText = ""
        vm.backText = "hello"
        vm.validate()
        XCTAssertEqual(vm.frontError, .missingFront)

        vm.frontText = "hi"
        vm.validate()

        XCTAssertNil(vm.frontError, "Valid front must clear the front error")
    }

    func test_validate_validBack_clearsBackError() {
        let store = makeStore()
        let vm = CardEditorViewModel(mode: .create(deckId: UUID()), store: store)

        vm.frontText = "hi"
        vm.backText = ""
        vm.validate()
        XCTAssertEqual(vm.backError, .missingBack)

        vm.backText = "hello"
        vm.validate()

        XCTAssertNil(vm.backError, "Valid back must clear the back error")
    }

    // MARK: - C3: Create success via InMemoryCardStore
    // Requirements: 1.2, 1.6, 1.7, 4.1

    func test_submit_createMode_validInput_persistsAndReturnsSnapshotWithExpectedDeckIds() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let store = makeStore(clock: { t })
        let deckId = UUID()
        let vm = CardEditorViewModel(mode: .create(deckId: deckId), store: store, clock: { t })

        vm.frontText = "hi"
        vm.backText = "hello"
        vm.validate()
        XCTAssertNil(vm.frontError)
        XCTAssertNil(vm.backError)

        let snapshot = try vm.submit()

        XCTAssertEqual(snapshot.frontText, "hi")
        XCTAssertEqual(snapshot.backText, "hello")
        XCTAssertEqual(snapshot.createdAt, t)
        XCTAssertEqual(snapshot.updatedAt, t)
        XCTAssertEqual(snapshot.deckIds, [deckId])

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, snapshot.id)
        XCTAssertEqual(all.first?.deckIds, [deckId])
    }

    func test_submit_createMode_nilDeckId_createsOrphan() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let store = makeStore(clock: { t })
        let vm = CardEditorViewModel(mode: .create(deckId: nil), store: store, clock: { t })

        vm.frontText = "hi"
        vm.backText = "hello"

        let snapshot = try vm.submit()

        XCTAssertTrue(snapshot.deckIds.isEmpty, "A nil deckId must produce an orphan snapshot")

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, snapshot.id)
        XCTAssertTrue(all.first?.deckIds.isEmpty ?? false)
    }

    // MARK: - C4: Edit success with updatedAt advancing
    // Requirements: 3.2, 3.5

    func test_submit_editMode_validInput_preservesIdCreatedAtDeckIds_bumpsUpdatedAt() throws {
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        let (clock, setClock) = makeMutableClock(initial: t1)
        let store = InMemoryCardStore(clock: clock)
        let deckId = UUID()

        let seeded = try store.create(frontText: "hi", backText: "hello", deckIds: [deckId])
        XCTAssertEqual(seeded.createdAt, t1)
        XCTAssertEqual(seeded.updatedAt, t1)

        setClock(t2)
        let vm = CardEditorViewModel(mode: .edit(seeded), store: store, clock: clock)
        vm.frontText = "こんにちは"
        vm.backText = "hello (edited)"

        let updated = try vm.submit()

        XCTAssertEqual(updated.id, seeded.id, "id must be preserved across edits")
        XCTAssertEqual(updated.createdAt, t1, "createdAt must be preserved across edits")
        XCTAssertEqual(updated.updatedAt, t2, "updatedAt must advance to the clock's current value")
        XCTAssertEqual(updated.deckIds, [deckId], "deckIds must be preserved across edits")
        XCTAssertEqual(updated.frontText, "こんにちは")
        XCTAssertEqual(updated.backText, "hello (edited)")

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, seeded.id)
        XCTAssertEqual(all.first?.frontText, "こんにちは")
        XCTAssertEqual(all.first?.backText, "hello (edited)")
        XCTAssertEqual(all.first?.createdAt, t1)
        XCTAssertEqual(all.first?.updatedAt, t2)
        XCTAssertEqual(all.first?.deckIds, [deckId])
    }

    // MARK: - C7: Orphan editing
    // Requirements: 6.1, 6.3, 6.4

    func test_editMode_orphanSnapshot_prepopulatesTextAndSubmitPreservesOrphanStatus() throws {
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        let (clock, setClock) = makeMutableClock(initial: t1)
        let store = InMemoryCardStore(clock: clock)

        // Seed an orphan card (deckIds == []).
        let orphan = try store.create(frontText: "orphan front", backText: "orphan back", deckIds: [])
        XCTAssertTrue(orphan.deckIds.isEmpty)

        setClock(t2)
        let vm = CardEditorViewModel(mode: .edit(orphan), store: store, clock: clock)

        // Edit-mode pre-populates the text from the snapshot.
        XCTAssertEqual(vm.frontText, "orphan front")
        XCTAssertEqual(vm.backText, "orphan back")

        vm.frontText = "edited orphan front"
        vm.backText = "edited orphan back"

        let updated = try vm.submit()

        XCTAssertTrue(updated.deckIds.isEmpty,
                      "Editing an orphan must preserve orphan status (deckIds stays empty)")
        XCTAssertEqual(updated.frontText, "edited orphan front")
        XCTAssertEqual(updated.backText, "edited orphan back")

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, orphan.id)
        XCTAssertTrue(all.first?.deckIds.isEmpty ?? false)
        XCTAssertEqual(all.first?.frontText, "edited orphan front")
        XCTAssertEqual(all.first?.backText, "edited orphan back")
    }

    func test_editMode_orphanSnapshot_deleteRemovesCard() throws {
        let store = makeStore()
        let orphan = try store.create(frontText: "orphan front", backText: "orphan back", deckIds: [])

        let vm = CardEditorViewModel(mode: .edit(orphan), store: store)
        try vm.delete()

        let all = try store.fetchAll()
        XCTAssertTrue(all.isEmpty, "delete() on an orphan must remove it from the store")
    }

    // MARK: - Delete (general)

    func test_delete_editMode_removesCardFromStore() throws {
        let store = makeStore()
        let deckId = UUID()
        let seeded = try store.create(frontText: "hi", backText: "hello", deckIds: [deckId])

        let vm = CardEditorViewModel(mode: .edit(seeded), store: store)
        try vm.delete()

        let all = try store.fetchAll()
        XCTAssertFalse(all.contains(where: { $0.id == seeded.id }),
                       "delete() in edit mode must remove the card from the store")
    }

    func test_delete_createMode_isNoOp() throws {
        let store = makeStore()
        let deckId = UUID()
        // Seed a separate card in the store to make sure delete() in .create mode
        // does not touch it (delete in .create mode is a no-op per design §ViewModels).
        let seeded = try store.create(frontText: "hi", backText: "hello", deckIds: [deckId])

        let vm = CardEditorViewModel(mode: .create(deckId: deckId), store: store)
        XCTAssertNoThrow(try vm.delete())

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, seeded.id,
                       "delete() in .create mode must be a no-op and must not remove other cards")
    }

    // MARK: - Submit-gating invariants: no `changes` emission on validation failure

    func test_submit_createMode_invalidInput_doesNotEmitOnChanges_afterValidationFailure() {
        let store = makeStore()
        let vm = CardEditorViewModel(mode: .create(deckId: UUID()), store: store)

        var count = 0
        var cancellables: Set<AnyCancellable> = []
        store.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        vm.frontText = ""
        vm.backText = "hello"
        XCTAssertThrowsError(try vm.submit())

        waitBriefly()

        XCTAssertEqual(count, 0, "Validation-failed submit in .create mode must not emit on changes")
    }

    func test_submit_editMode_invalidInput_doesNotEmitOnChanges_afterValidationFailure() throws {
        let store = makeStore()
        let deckId = UUID()
        let seeded = try store.create(frontText: "original front", backText: "original back", deckIds: [deckId])

        let vm = CardEditorViewModel(mode: .edit(seeded), store: store)

        var count = 0
        var cancellables: Set<AnyCancellable> = []
        store.changes
            .sink { count += 1 }
            .store(in: &cancellables)

        vm.frontText = "changed front"
        vm.backText = ""
        XCTAssertThrowsError(try vm.submit())

        waitBriefly()

        XCTAssertEqual(count, 0, "Validation-failed submit in .edit mode must not emit on changes")
    }
}
