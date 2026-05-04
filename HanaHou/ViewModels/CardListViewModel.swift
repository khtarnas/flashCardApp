//
//  CardListViewModel.swift
//  HanaHou
//
//  Feature: card-management
//

import Foundation
import Combine

/// Drives the per-Deck card list. Subscribes to `CardStore.changes` and
/// re-queries `fetchInDeck(deckId:)` on each signal, applying the injected
/// `CardOrderingStrategy`. Exposes `[CardRowItem]` to the view along with a
/// `snapshot(forRowId:)` accessor so a tapped row can be resolved back to
/// its `CardSnapshot` for navigation to `.editCard(snapshot)`.
@MainActor
final class CardListViewModel: ObservableObject {

    @Published private(set) var items: [CardRowItem] = []
    @Published var loadError: Error?

    let deckId: UUID

    private let store: CardStore
    private let strategy: CardOrderingStrategy
    private var snapshotsById: [UUID: CardSnapshot] = [:]
    private var cancellables: Set<AnyCancellable> = []

    init(deckId: UUID, store: CardStore, strategy: CardOrderingStrategy) {
        self.deckId = deckId
        self.store = store
        self.strategy = strategy

        store.changes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.reload() }
            .store(in: &cancellables)

        reload()
    }

    /// Explicit reload. Called from init and on every `store.changes` signal.
    /// Useful for tests that want to avoid the runloop hop.
    func reload() {
        do {
            let cards = try store.fetchInDeck(deckId: deckId)
            let ordered = strategy.order(cards)
            snapshotsById = Dictionary(uniqueKeysWithValues: ordered.map { ($0.id, $0) })
            items = ordered.map { snapshot in
                CardRowItem(
                    id: snapshot.id,
                    frontText: snapshot.frontText,
                    backText: snapshot.backText,
                    isOrphan: snapshot.deckIds.isEmpty
                )
            }
            loadError = nil
        } catch {
            // Preserve any items already shown rather than blanking the list
            // on a transient fetch failure — the view can still render stale
            // rows while `loadError` is surfaced in an alert.
            loadError = error
        }
    }

    /// Clears a previously-surfaced `loadError`. Called by the view after the
    /// user dismisses the error alert.
    func acknowledgeLoadError() {
        loadError = nil
    }

    /// Resolves a tapped `CardRowItem.id` back to its underlying `CardSnapshot`
    /// so the view can push `.editCard(snapshot)` with the full value type.
    /// Returns `nil` for unknown ids.
    func snapshot(forRowId id: UUID) -> CardSnapshot? {
        snapshotsById[id]
    }

    /// Deletes the card via the store. Surfaces any store error to the caller.
    func delete(id: UUID) throws {
        try store.delete(id: id)
    }
}
