//
//  DeckManagementRootView.swift
//  HanaHou
//
//  Feature: deck-management
//

import SwiftUI

struct DeckManagementRootView: View {
    @StateObject private var viewModel: DeckListViewModel
    @State private var path = NavigationPath()
    private let store: DeckStore
    private let clock: () -> Date

    init(store: DeckStore, strategy: DeckOrderingStrategy, clock: @escaping () -> Date = Date.init) {
        self.store = store
        self.clock = clock
        _viewModel = StateObject(wrappedValue: DeckListViewModel(store: store, strategy: strategy))
    }

    var body: some View {
        NavigationStack(path: $path) {
            DeckListView(viewModel: viewModel) { route in
                path.append(route)
            }
            .navigationDestination(for: DeckManagementRoute.self) { route in
                switch route {
                case .createDeck:
                    DeckEditorView(
                        viewModel: DeckEditorViewModel(mode: .create, store: store, clock: clock),
                        onFinish: { path.removeLast() }
                    )
                case .editDeck(let snapshot):
                    DeckEditorView(
                        viewModel: DeckEditorViewModel(mode: .edit(snapshot), store: store, clock: clock),
                        onFinish: { path.removeLast() }
                    )
                case .allCards:
                    AllCardsPlaceholderView()
                }
            }
        }
    }
}

/// Routes pushable onto the deck-management navigation stack.
enum DeckManagementRoute: Hashable {
    case createDeck
    case editDeck(DeckSnapshot)
    case allCards
}
