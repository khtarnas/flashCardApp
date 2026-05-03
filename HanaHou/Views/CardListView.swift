//
//  CardListView.swift
//  HanaHou
//
//  Feature: card-management
//

import SwiftUI

/// Per-Deck card list. Displays every card associated with `deck`, routes
/// row taps to the card editor, provides a toolbar "+" to create a new
/// card in this deck, and exposes an "Edit deck" toolbar action that
/// pushes the deck editor (design-approved relocation away from the
/// user-deck row tap).
struct CardListView: View {
    let deck: DeckSnapshot
    @ObservedObject var viewModel: CardListViewModel
    let onNavigate: (DeckManagementRoute) -> Void

    @State private var rowPendingDelete: CardRowItem?

    var body: some View {
        List {
            ForEach(viewModel.items, id: \.id) { row in
                Button {
                    if let snapshot = viewModel.snapshot(forRowId: row.id) {
                        onNavigate(.editCard(snapshot))
                    }
                } label: {
                    rowContent(row)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        rowPendingDelete = row
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .overlay {
            if viewModel.items.isEmpty {
                emptyStateLabel
            }
        }
        .navigationTitle(deck.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onNavigate(.createCard(deckId: deck.id))
                } label: {
                    Label("New Card", systemImage: "plus")
                }
                .accessibilityIdentifier("NewCardButton")
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onNavigate(.editDeck(deck))
                } label: {
                    Label("Edit Deck", systemImage: "pencil")
                }
                .accessibilityIdentifier("EditDeckButton")
            }
        }
        .confirmationDialog(
            "Delete this card?",
            isPresented: Binding(
                get: { rowPendingDelete != nil },
                set: { if !$0 { rowPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: rowPendingDelete
        ) { row in
            Button("Delete", role: .destructive) {
                try? viewModel.delete(id: row.id)
                rowPendingDelete = nil
            }
            Button("Cancel", role: .cancel) { rowPendingDelete = nil }
        } message: { _ in
            Text("This can't be undone.")
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func rowContent(_ row: CardRowItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.frontText)
                .font(.body)
                .foregroundStyle(.primary)
            Text(row.backText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var emptyStateLabel: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No cards yet.")
                .font(.headline)
            Text("Tap + to add one.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
