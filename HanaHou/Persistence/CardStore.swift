//
//  CardStore.swift
//  HanaHou
//
//  Feature: card-management
//

import Foundation
import Combine

/// Persistence seam for Card CRUD and per-Deck querying.
///
/// Mirrors `DeckStore` in every contract detail so both stores behave
/// identically from the view-model layer's perspective. Two conforming
/// implementations are supplied: `CoreDataCardStore` for production and
/// `InMemoryCardStore` for view-model and editor tests (Req 7 AC 10).
protocol CardStore {
    /// Returns every Card in the store regardless of Deck membership,
    /// including orphaned Cards (those with `deckIds.isEmpty`). Order is
    /// unspecified — callers apply a `CardOrderingStrategy`.
    func fetchAll() throws -> [CardSnapshot]

    /// Returns every Card associated with the given Deck id. Order is
    /// unspecified — callers apply a `CardOrderingStrategy`.
    func fetchInDeck(deckId: UUID) throws -> [CardSnapshot]

    /// Creates a new Card with the given text and initial Deck membership.
    ///
    /// `deckIds` may be empty — creating an orphan Card is permitted. The
    /// P0 per-Deck editor supplies a singleton set containing the current
    /// Deck's id. Both `createdAt` and `updatedAt` are set to the store's
    /// clock's current value on insert (Req 1 AC 6, Req 7 AC 6, D024).
    func create(
        frontText: String,
        backText: String,
        deckIds: Set<UUID>
    ) throws -> CardSnapshot

    /// Replaces the Card's text content.
    ///
    /// Bumps `updatedAt` to the clock's current value (Req 3 AC 5, D024).
    /// Preserves `id`, `createdAt`, and `deckIds` (Req 3 AC 5). Updating a
    /// Card whose id is not in the store is a silent no-op — the operation
    /// is idempotent. Implementations MUST NOT emit on `changes` for a
    /// no-op update (Req 7 AC 9).
    func update(id: UUID, frontText: String, backText: String) throws

    /// Removes the Card with the given id.
    ///
    /// Detaches the Card from every Deck it was associated with
    /// (Req 4 AC 3) without deleting any Deck (Req 4 AC 4). Deleting a
    /// non-existent id is a silent no-op — the operation is idempotent.
    /// Implementations MUST NOT emit on `changes` for a no-op delete
    /// (Req 7 AC 9).
    func delete(id: UUID) throws

    /// Emits once per successful mutation (create, update, or delete).
    ///
    /// Does not emit for validation failures or unknown-id no-ops. View
    /// models subscribe to this publisher and re-query on each signal
    /// (Req 7 AC 8).
    var changes: AnyPublisher<Void, Never> { get }
}

enum CardStoreError: Error {
    case persistenceFailed(underlying: Error)
}
