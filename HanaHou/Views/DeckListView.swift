//
//  DeckListView.swift
//  HanaHou
//
//  Feature: deck-management
//

import SwiftUI

struct DeckListView: View {
    @ObservedObject var viewModel: DeckListViewModel
    let onNavigate: (DeckManagementRoute) -> Void

    @State private var deckPendingDelete: DeckSnapshot?

    var body: some View {
        List {
            ForEach(viewModel.items, id: \.id) { item in
                row(for: item)
            }
        }
        .overlay {
            if !hasUserDecks {
                emptyStateLabel
            }
        }
        .navigationTitle("Decks")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onNavigate(.createDeck)
                } label: {
                    Label("New Deck", systemImage: "plus")
                }
                .accessibilityIdentifier("NewDeckButton")
            }
        }
        .confirmationDialog(
            deckPendingDelete.map { "Delete \"\($0.name)\"?" } ?? "",
            isPresented: Binding(
                get: { deckPendingDelete != nil },
                set: { if !$0 { deckPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: deckPendingDelete
        ) { snapshot in
            Button("Delete", role: .destructive) {
                try? viewModel.delete(item: .deck(snapshot))
                deckPendingDelete = nil
            }
            Button("Cancel", role: .cancel) { deckPendingDelete = nil }
        } message: { _ in
            Text("Cards in this deck will be kept and remain visible in All Cards.")
        }
    }

    @ViewBuilder
    private func row(for item: DeckListItem) -> some View {
        switch item {
        case .allCards:
            Button {
                onNavigate(.allCards)
            } label: {
                Label("All Cards", systemImage: "square.stack.3d.up")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .accessibilityIdentifier("AllCardsRow")

        case .deck(let snapshot):
            Button {
                // Tapping a user-deck row opens the deck's card list, not
                // the deck editor. "Edit deck" is reachable from the card
                // list's toolbar (approved card-management design decision).
                onNavigate(.cardList(snapshot))
            } label: {
                deckRowContent(snapshot)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    deckPendingDelete = snapshot
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func deckRowContent(_ snapshot: DeckSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.name)
                .font(.body)
                .foregroundStyle(.primary)
            Text("\(snapshot.frontLanguage.displayName) → \(snapshot.backLanguage.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var hasUserDecks: Bool {
        viewModel.items.contains {
            if case .deck = $0 { return true }
            return false
        }
    }

    @ViewBuilder
    private var emptyStateLabel: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.stack")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No decks yet.")
                .font(.headline)
            Text("Tap + to create one.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
