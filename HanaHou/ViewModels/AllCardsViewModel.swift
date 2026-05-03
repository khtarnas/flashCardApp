//
//  AllCardsViewModel.swift
//  HanaHou
//
//  Feature: card-management
//

import Foundation
import Combine

/// Drives the All Cards view. Near-duplicate of `CardListViewModel` but
/// queries `store.fetchAll()` so every Card in the store is surfaced —
/// including orphaned Cards whose last associated Deck has been deleted
/// (per Req 5.2 / 6.2). Orphan rows are flagged via `CardRowItem.isOrphan`.
///
/// Unifying `AllCardsViewModel` and `CardListViewModel` was considered and
/// rejected in the design: the two cases don't share enough behavior to
/// justify the branching (see design §ViewModels / "AllCardsViewModel").
@MainActor
final class AllCardsViewModel: ObservableObject {

    @Published private(set) var items: [CardRowItem] = []

    private let store: CardStore
    private let strategy: CardOrderingStrategy
    private var snapshotsById: [UUID: CardSnapshot] = [:]
    private var cancellables: Set<AnyCancellable> = []

    init(store: CardStore, strategy: CardOrderingStrategy) {
        self.store = store
        self.strategy = strategy

        store.changes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.reload() }
            .store(in: &cancellables)

        reload()
    }

    /// Explicit reload. Called from init and on every `store.changes` signal.
    func reload() {
        let cards = (try? store.fetchAll()) ?? []
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
    }

    /// Resolves a tapped `CardRowItem.id` back to its underlying `CardSnapshot`
    /// so the view can push `.editCard(snapshot)` with the full value type.
    func snapshot(forRowId id: UUID) -> CardSnapshot? {
        snapshotsById[id]
    }

    /// Deletes the card via the store. Surfaces any store error to the caller.
    func delete(id: UUID) throws {
        try store.delete(id: id)
    }
}
