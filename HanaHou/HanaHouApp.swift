//
//  HanaHouApp.swift
//  HanaHou
//
//  Feature: deck-management (composition root)
//

import SwiftUI

@main
struct HanaHouApp: App {
    // Composition root: instantiate the persistence stack, vend a DeckStore,
    // and pick the P0 ordering strategy. Swapping the store or strategy in a
    // future priority is a one-line change right here.
    private let persistenceController = PersistenceController.shared
    private let orderingStrategy: DeckOrderingStrategy = CreationDateAscendingOrdering()

    var body: some Scene {
        WindowGroup {
            if let loadError = persistenceController.loadError {
                PersistenceLoadErrorView(error: loadError)
            } else {
                DeckManagementRootView(
                    store: persistenceController.makeDeckStore(),
                    strategy: orderingStrategy
                )
            }
        }
    }
}

/// Surfaced when Core Data fails to load. Keeps the app from crashing and
/// gives the user something actionable.
private struct PersistenceLoadErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Couldn't load your data")
                .font(.title2.weight(.semibold))
            Text(error.localizedDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}
