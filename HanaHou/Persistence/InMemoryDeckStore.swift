//
//  InMemoryDeckStore.swift
//  HanaHou
//
//  Feature: deck-management
//

import Foundation
import Combine

final class InMemoryDeckStore: DeckStore {

    private var decks: [UUID: DeckSnapshot] = [:]
    private let changesSubject = PassthroughSubject<Void, Never>()

    var clock: () -> Date

    init(clock: @escaping () -> Date = Date.init) {
        self.clock = clock
    }

    // Explicit `nonisolated deinit` sidesteps the Swift 6 isolated-deinit
    // path that can trap (libmalloc "pointer being freed was not
    // allocated") when a MainActor-isolated reference type is deallocated
    // synchronously from the main thread under Xcode 26 / iOS 26. The
    // store holds no resources that need main-actor cleanup.
    nonisolated deinit {}

    var changes: AnyPublisher<Void, Never> {
        changesSubject.eraseToAnyPublisher()
    }

    func fetchAll() throws -> [DeckSnapshot] {
        Array(decks.values)
    }

    func create(_ draft: DeckDraft) throws -> DeckSnapshot {
        switch DeckNameValidator.validate(
            name: draft.name,
            against: Array(decks.values),
            editingDeckId: nil
        ) {
        case .failure(let nameError):
            throw nameError
        case .success:
            break
        }

        let now = clock()
        let snapshot = DeckSnapshot(
            id: UUID(),
            name: draft.name,
            frontLanguage: draft.frontLanguage,
            backLanguage: draft.backLanguage,
            createdAt: now,
            updatedAt: now
        )
        decks[snapshot.id] = snapshot
        changesSubject.send()
        return snapshot
    }

    func update(id: UUID, with draft: DeckDraft) throws -> DeckSnapshot {
        guard let existing = decks[id] else {
            let underlying = NSError(
                domain: "HanaHou.InMemoryDeckStore",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "deck not found"]
            )
            throw DeckStoreError.persistenceFailed(underlying: underlying)
        }

        switch DeckNameValidator.validate(
            name: draft.name,
            against: Array(decks.values),
            editingDeckId: id
        ) {
        case .failure(let nameError):
            throw nameError
        case .success:
            break
        }

        let snapshot = DeckSnapshot(
            id: existing.id,
            name: draft.name,
            frontLanguage: draft.frontLanguage,
            backLanguage: draft.backLanguage,
            createdAt: existing.createdAt,
            updatedAt: clock()
        )
        decks[id] = snapshot
        changesSubject.send()
        return snapshot
    }

    func delete(id: UUID) throws {
        if decks.removeValue(forKey: id) != nil {
            changesSubject.send()
        }
    }
}
