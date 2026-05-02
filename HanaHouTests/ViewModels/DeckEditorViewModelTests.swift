//
//  DeckEditorViewModelTests.swift
//  HanaHouTests
//
//  Feature: deck-management
//  Covers behaviors: B1 (empty), B2 (reserved), B3 (duplicate w/ self-exclusion), B4 (distinct messages), B5 (create success via InMemoryDeckStore), B6 (edit success w/ updatedAt advancing)
//  Validates requirements: 2.1, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 5.1, 5.2, 5.3, 5.4, 5.5
//

import XCTest
@testable import HanaHou

@MainActor
final class DeckEditorViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeStore(
        clock: @escaping () -> Date = { Date(timeIntervalSince1970: 1_000) }
    ) -> InMemoryDeckStore {
        InMemoryDeckStore(clock: clock)
    }

    /// Returns a mutable clock closure plus a setter, so tests can advance time.
    private func makeMutableClock(initial: Date) -> (clock: () -> Date, set: (Date) -> Void) {
        final class Box { var date: Date; init(_ d: Date) { self.date = d } }
        let box = Box(initial)
        return ({ box.date }, { box.date = $0 })
    }

    private func makeDraft(
        name: String = "Japanese",
        front: Language = .english,
        back: Language = .japanese
    ) -> DeckDraft {
        DeckDraft(name: name, frontLanguage: front, backLanguage: back)
    }

    // MARK: - Initialization

    func test_createMode_initializesWithEmptyDefaults() {
        let store = makeStore()

        let vm = DeckEditorViewModel(mode: .create, store: store)

        XCTAssertEqual(vm.name, "")
        XCTAssertNil(vm.nameError)
    }

    func test_editMode_prepopulatesFromSnapshot() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let store = makeStore(clock: { t })
        let seeded = try store.create(
            makeDraft(name: "Japanese", front: .english, back: .japanese)
        )

        let vm = DeckEditorViewModel(mode: .edit(seeded), store: store)

        XCTAssertEqual(vm.name, seeded.name)
        XCTAssertEqual(vm.frontLanguage, seeded.frontLanguage)
        XCTAssertEqual(vm.backLanguage, seeded.backLanguage)
        XCTAssertNil(vm.nameError)
    }

    // MARK: - B1: Empty name validation
    // Requirements: 2.4, 3.3, 5.1, 5.4

    func test_validateName_emptyName_setsNameErrorToEmpty() {
        let store = makeStore()
        let vm = DeckEditorViewModel(mode: .create, store: store)

        vm.name = "   "
        try? vm.validateName()

        guard case .empty = vm.nameError else {
            XCTFail("Expected nameError to be .empty, got \(String(describing: vm.nameError))")
            return
        }
    }

    // MARK: - B2: Reserved name validation
    // Requirements: 2.6, 3.5, 5.3, 5.4

    func test_validateName_reservedName_setsNameErrorToReserved() {
        let store = makeStore()
        let vm = DeckEditorViewModel(mode: .create, store: store)

        vm.name = "All Cards"
        try? vm.validateName()

        guard case .reserved = vm.nameError else {
            XCTFail("Expected nameError to be .reserved, got \(String(describing: vm.nameError))")
            return
        }
    }

    // MARK: - B3: Duplicate name validation (with edit-mode self-exclusion)
    // Requirements: 2.5, 3.4, 5.2, 5.4

    func test_validateName_duplicateName_setsNameErrorToDuplicate() throws {
        let store = makeStore()
        _ = try store.create(makeDraft(name: "Japanese"))
        let vm = DeckEditorViewModel(mode: .create, store: store)

        vm.name = "Japanese"
        try? vm.validateName()

        guard case .duplicate = vm.nameError else {
            XCTFail("Expected nameError to be .duplicate, got \(String(describing: vm.nameError))")
            return
        }
    }

    func test_validateName_validName_setsNameErrorToNil() {
        let store = makeStore()
        let vm = DeckEditorViewModel(mode: .create, store: store)

        vm.name = "Japanese"
        try? vm.validateName()

        XCTAssertNil(vm.nameError)
    }

    func test_validateName_editModeSameNameAsSelf_succeeds() throws {
        let store = makeStore()
        let seeded = try store.create(makeDraft(name: "Japanese"))
        let vm = DeckEditorViewModel(mode: .edit(seeded), store: store)

        vm.name = "Japanese"
        try? vm.validateName()

        XCTAssertNil(vm.nameError, "Resubmitting an edited deck's own name must not be flagged as a duplicate")
    }

    // MARK: - B4: Distinct error messages
    // Requirements: 5.5

    func test_messages_areDistinctAcrossCases() {
        let emptyMessage = DeckEditorViewModel.message(for: .empty)
        let reservedMessage = DeckEditorViewModel.message(for: .reserved(name: "All Cards"))
        let duplicateMessage = DeckEditorViewModel.message(for: .duplicate(name: "Japanese"))

        XCTAssertFalse(emptyMessage.isEmpty, "Empty-case message must be non-empty")
        XCTAssertFalse(reservedMessage.isEmpty, "Reserved-case message must be non-empty")
        XCTAssertFalse(duplicateMessage.isEmpty, "Duplicate-case message must be non-empty")

        XCTAssertNotEqual(emptyMessage, reservedMessage)
        XCTAssertNotEqual(emptyMessage, duplicateMessage)
        XCTAssertNotEqual(reservedMessage, duplicateMessage)
    }

    // MARK: - B5: Create success via InMemoryDeckStore
    // Requirements: 2.1, 2.3, 2.7, 2.8

    func test_submit_createMode_validDraft_persistsAndReturnsSnapshot() throws {
        let t = Date(timeIntervalSince1970: 1_000)
        let store = makeStore(clock: { t })
        let vm = DeckEditorViewModel(mode: .create, store: store)

        vm.name = "Japanese"
        vm.frontLanguage = .english
        vm.backLanguage = .japanese
        try? vm.validateName()

        let snapshot = try vm.submit()

        XCTAssertEqual(snapshot.name, "Japanese")
        XCTAssertEqual(snapshot.frontLanguage, .english)
        XCTAssertEqual(snapshot.backLanguage, .japanese)
        XCTAssertEqual(snapshot.createdAt, t)
        XCTAssertEqual(snapshot.updatedAt, t)

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, snapshot.id)
        XCTAssertEqual(all.first?.name, "Japanese")
    }

    func test_submit_createMode_invalidName_throwsAndDoesNotPersist() throws {
        let store = makeStore()
        let vm = DeckEditorViewModel(mode: .create, store: store)

        vm.name = "   "

        XCTAssertThrowsError(try vm.submit())

        let all = try store.fetchAll()
        XCTAssertTrue(all.isEmpty, "Failed submit must not persist anything")
    }

    // MARK: - B6: Edit success with updatedAt advancing
    // Requirements: 3.1, 3.2, 3.6

    func test_submit_editMode_validDraft_preservesIdAndCreatedAt_setsUpdatedAt() throws {
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        let (clock, setClock) = makeMutableClock(initial: t1)
        let store = InMemoryDeckStore(clock: clock)

        let seeded = try store.create(
            makeDraft(name: "Japanese", front: .english, back: .japanese)
        )
        XCTAssertEqual(seeded.createdAt, t1)
        XCTAssertEqual(seeded.updatedAt, t1)

        setClock(t2)
        let vm = DeckEditorViewModel(mode: .edit(seeded), store: store)
        vm.name = "日本語"
        try? vm.validateName()

        let updated = try vm.submit()

        XCTAssertEqual(updated.id, seeded.id)
        XCTAssertEqual(updated.createdAt, t1, "createdAt must be preserved across edits")
        XCTAssertEqual(updated.updatedAt, t2, "updatedAt must advance to the clock's current value")
        XCTAssertEqual(updated.name, "日本語")
        XCTAssertEqual(updated.frontLanguage, .english)
        XCTAssertEqual(updated.backLanguage, .japanese)

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, seeded.id)
        XCTAssertEqual(all.first?.name, "日本語")
        XCTAssertEqual(all.first?.createdAt, t1)
        XCTAssertEqual(all.first?.updatedAt, t2)
    }

    func test_submit_editMode_duplicateName_throws() throws {
        let store = makeStore()
        _ = try store.create(makeDraft(name: "Japanese"))
        let korean = try store.create(makeDraft(name: "Korean"))
        let before = try store.fetchAll()

        let vm = DeckEditorViewModel(mode: .edit(korean), store: store)
        vm.name = "Japanese"

        XCTAssertThrowsError(try vm.submit())

        let after = try store.fetchAll()
        XCTAssertEqual(after.count, before.count, "Failed edit must not change deck count")
        let names = Set(after.map(\.name))
        XCTAssertEqual(names, Set(["Japanese", "Korean"]), "Failed edit must not mutate existing names")
    }
}
