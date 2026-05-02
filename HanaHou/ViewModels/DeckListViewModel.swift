//
//  DeckListViewModel.swift
//  HanaHou
//
//  Feature: deck-management
//

import Foundation
import Combine

@MainActor
final class DeckListViewModel: ObservableObject {

    @Published private(set) var items: [DeckListItem] = []

    private let store: DeckStore
    private let strategy: DeckOrderingStrategy
    private var cancellables: Set<AnyCancellable> = []

    init(store: DeckStore, strategy: DeckOrderingStrategy) {
        self.store = store
        self.strategy = strategy

        store.changes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.reload() }
            .store(in: &cancellables)

        reload()
    }

    /// Explicit reload. Useful for tests; also called from init and on store changes.
    func reload() {
        let userDecks = (try? store.fetchAll()) ?? []
        items = DeckListComposer.compose(userDecks: userDecks, strategy: strategy)
    }

    /// Defense-in-depth guard for programmatic callers. Views never surface
    /// rename/delete affordances for `.allCards`.
    func rename(item: DeckListItem, to newName: String) throws {
        switch item {
        case .allCards:
            throw AllCardsActionError.notAllowed
        case .deck(let snapshot):
            let draft = DeckDraft(
                name: newName,
                frontLanguage: snapshot.frontLanguage,
                backLanguage: snapshot.backLanguage
            )
            _ = try store.update(id: snapshot.id, with: draft)
        }
    }

    func delete(item: DeckListItem) throws {
        switch item {
        case .allCards:
            throw AllCardsActionError.notAllowed
        case .deck(let snapshot):
            try store.delete(id: snapshot.id)
        }
    }
}
