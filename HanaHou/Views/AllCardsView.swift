//
//  AllCardsView.swift
//  HanaHou
//
//  Feature: card-management
//

import SwiftUI

/// All Cards view. Surfaces every Card in the store regardless of deck
/// membership, including orphaned cards whose last associated deck was
/// deleted (per Req 5.2 / 6.2). Tapping any row — orphan or not — pushes
/// `.editCard(snapshot)`; swipe-to-delete is wired directly to
/// `viewModel.delete(id:)`. No "+" affordance at P0 (design-approved).
struct AllCardsView: View {
    @ObservedObject var viewModel: AllCardsViewModel
    let onNavigate: (DeckManagementRoute) -> Void

    @State private var rowPendingDelete: CardRowItem?
    @State private var deleteError: Error?

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
        .navigationTitle("All Cards")
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
                do {
                    try viewModel.delete(id: row.id)
                } catch {
                    deleteError = error
                }
                rowPendingDelete = nil
            }
            Button("Cancel", role: .cancel) { rowPendingDelete = nil }
        } message: { _ in
            Text("This can't be undone.")
        }
        .alert(
            "Couldn't load cards",
            isPresented: Binding(
                get: { viewModel.loadError != nil },
                set: { if !$0 { viewModel.acknowledgeLoadError() } }
            ),
            presenting: viewModel.loadError
        ) { _ in
            Button("OK", role: .cancel) { viewModel.acknowledgeLoadError() }
        } message: { error in
            Text(error.localizedDescription)
        }
        .alert(
            "Couldn't delete card",
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            ),
            presenting: deleteError
        ) { _ in
            Button("OK", role: .cancel) { deleteError = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func rowContent(_ row: CardRowItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(row.frontText)
                    .font(.body)
                    .foregroundStyle(.primary)
                if row.isOrphan {
                    Spacer()
                    Text("Not in any deck")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: .capsule)
                }
            }
            Text(row.backText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var emptyStateLabel: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No cards yet.")
                .font(.headline)
        }
        .padding()
    }
}
