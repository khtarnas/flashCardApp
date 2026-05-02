//
//  DeckStore.swift
//  HanaHou
//
//  Feature: deck-management
//

import Foundation
import Combine

protocol DeckStore {
    func fetchAll() throws -> [DeckSnapshot]
    func create(_ draft: DeckDraft) throws -> DeckSnapshot
    func update(id: UUID, with draft: DeckDraft) throws -> DeckSnapshot

    /// Removes the deck with the given id.
    ///
    /// Deleting a non-existent id is a silent no-op — the operation is idempotent.
    /// Implementations MUST NOT emit on `changes` for a no-op delete.
    func delete(id: UUID) throws

    var changes: AnyPublisher<Void, Never> { get }
}

enum DeckStoreError: Error {
    case persistenceFailed(underlying: Error)
}
