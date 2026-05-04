//
//  InMemoryCardStore.swift
//  HanaHou
//
//  Feature: card-management
//

import Foundation
import Combine

/// In-memory `CardStore` for tests. Mirrors `InMemoryDeckStore` in shape:
/// backing state is a `[UUID: CardSnapshot]` map; mutations emit on a
/// `PassthroughSubject<Void, Never>` only when they actually change state.
/// Validation (`CardTextValidator`) is re-run inside `create` / `update` as
/// defense-in-depth matching `CoreDataCardStore`. Unknown-id `update`/`delete`
/// are silent no-ops and do NOT emit on `changes` (Req 7 AC 9).
final class InMemoryCardStore: CardStore {

    private var cards: [UUID: CardSnapshot] = [:]
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

    func fetchAll() throws -> [CardSnapshot] {
        Array(cards.values)
    }

    func fetchInDeck(deckId: UUID) throws -> [CardSnapshot] {
        cards.values.filter { $0.deckIds.contains(deckId) }
    }

    func create(frontText: String, backText: String, deckIds: Set<UUID>) throws -> CardSnapshot {
        let draft = CardDraft(frontText: frontText, backText: backText)
        switch CardTextValidator.validate(draft: draft) {
        case .failure(let textError):
            throw textError
        case .success:
            break
        }

        let now = clock()
        let snapshot = CardSnapshot(
            id: UUID(),
            frontText: frontText,
            backText: backText,
            createdAt: now,
            updatedAt: now,
            deckIds: deckIds
        )
        cards[snapshot.id] = snapshot
        changesSubject.send()
        return snapshot
    }

    func update(id: UUID, frontText: String, backText: String) throws {
        // Unknown-id update is a silent no-op (Req 7 AC 9). We intentionally
        // check for existence BEFORE validation: a no-op must not throw a
        // validation error either.
        guard let existing = cards[id] else {
            return
        }

        let draft = CardDraft(frontText: frontText, backText: backText)
        switch CardTextValidator.validate(draft: draft) {
        case .failure(let textError):
            throw textError
        case .success:
            break
        }

        let snapshot = CardSnapshot(
            id: existing.id,
            frontText: frontText,
            backText: backText,
            createdAt: existing.createdAt,
            updatedAt: clock(),
            deckIds: existing.deckIds
        )
        cards[id] = snapshot
        changesSubject.send()
    }

    func delete(id: UUID) throws {
        if cards.removeValue(forKey: id) != nil {
            changesSubject.send()
        }
    }

    // MARK: - Test-only helpers
    //
    // Not part of the `CardStore` protocol. Provides a way for view-model
    // tests to simulate the shared-context `NSManagedObjectContextDidSave`
    // path without a real Core Data stack (per design §Persistence Layer /
    // "InMemoryCardStore").

    /// Removes `deckId` from every stored snapshot's `deckIds`. Emits one
    /// `changes` signal iff any snapshot actually changed. Does NOT emit
    /// when no snapshot references the deck id (parity with the
    /// "emit only on state change" invariant).
    func simulateDeckDeleted(deckId: UUID) {
        var changed = false
        for (id, snapshot) in cards where snapshot.deckIds.contains(deckId) {
            var newDeckIds = snapshot.deckIds
            newDeckIds.remove(deckId)
            cards[id] = CardSnapshot(
                id: snapshot.id,
                frontText: snapshot.frontText,
                backText: snapshot.backText,
                createdAt: snapshot.createdAt,
                updatedAt: snapshot.updatedAt,
                deckIds: newDeckIds
            )
            changed = true
        }
        if changed {
            changesSubject.send()
        }
    }
}
