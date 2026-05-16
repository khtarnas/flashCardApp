//
//  DeckManagementRootView.swift
//  HanaHou
//
//  Feature: deck-management + card-management (composition root for deck/card UI)
//

import SwiftUI

struct DeckManagementRootView: View {
    @StateObject private var viewModel: DeckListViewModel
    @State private var path = NavigationPath()

    private let deckStore: DeckStore
    private let cardStore: CardStore
    private let cardStrategy: CardOrderingStrategy
    private let clock: () -> Date

    init(
        deckStore: DeckStore,
        cardStore: CardStore,
        deckStrategy: DeckOrderingStrategy,
        cardStrategy: CardOrderingStrategy,
        clock: @escaping () -> Date = Date.init
    ) {
        self.deckStore = deckStore
        self.cardStore = cardStore
        self.cardStrategy = cardStrategy
        self.clock = clock
        _viewModel = StateObject(wrappedValue: DeckListViewModel(store: deckStore, strategy: deckStrategy))
    }

    var body: some View {
        NavigationStack(path: $path) {
            DeckListView(viewModel: viewModel) { route in
                path.append(route)
            }
            .navigationDestination(for: DeckManagementRoute.self) { route in
                destination(for: route)
            }
        }
    }

    // MARK: - Navigation destinations

    @ViewBuilder
    private func destination(for route: DeckManagementRoute) -> some View {
        switch route {
        case .createDeck:
            DeckEditorView(
                viewModel: DeckEditorViewModel(mode: .create, store: deckStore, clock: clock),
                onFinish: { path.removeLast() }
            )
        case .editDeck(let snapshot):
            DeckEditorView(
                viewModel: DeckEditorViewModel(mode: .edit(snapshot), store: deckStore, clock: clock),
                onFinish: { path.removeLast() }
            )
        case .allCards:
            AllCardsView(
                viewModel: AllCardsViewModel(store: cardStore, strategy: cardStrategy)
            ) { route in
                path.append(route)
            }
        case .cardList(let deck):
            CardListView(
                deck: deck,
                viewModel: CardListViewModel(deckId: deck.id, store: cardStore, strategy: cardStrategy)
            ) { route in
                path.append(route)
            }
        case .createCard(let deckId):
            CardEditorView(
                viewModel: CardEditorViewModel(
                    mode: .create(deckId: deckId),
                    store: cardStore,
                    clock: clock
                ),
                onFinish: { path.removeLast() }
            )
        case .editCard(let snapshot):
            CardEditorView(
                viewModel: CardEditorViewModel(
                    mode: .edit(snapshot),
                    store: cardStore,
                    clock: clock
                ),
                onFinish: { path.removeLast() }
            )
        case .study(let deck):
            StudyView(
                deck: deck,
                viewModel: StudySessionViewModel(
                    deckId: deck.id,
                    store: cardStore,
                    strategy: cardStrategy
                ),
                onExit: { path.removeLast() },
                onReturnHome: { path.removeLast(path.count) }
            )
        }
    }
}

/// Routes pushable onto the deck-management navigation stack.
enum DeckManagementRoute: Hashable {
    case createDeck
    case editDeck(DeckSnapshot)
    case allCards
    case cardList(DeckSnapshot)
    case createCard(deckId: UUID)
    case editCard(CardSnapshot)
    case study(DeckSnapshot)
}
