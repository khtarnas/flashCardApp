//
//  CardEditorViewModel.swift
//  HanaHou
//
//  Feature: card-management
//

import Foundation
import Combine

/// View model for creating and editing a Card. Unifies the two flows
/// via the `Mode` enum; the view routes to the same surface in either case
/// (`.create(deckId:)` or `.edit(CardSnapshot)`).
///
/// Validation uses two independent `@Published` error channels (`frontError`,
/// `backError`) so the editor view can render inline messages for each field
/// concurrently — both errors can be non-nil at the same time when both
/// fields are empty (per design §ViewModels).
@MainActor
final class CardEditorViewModel: ObservableObject {

    enum Mode: Equatable {
        /// `deckId` is optional so a future "create from All Cards" surface
        /// can create an orphan card. P0's per-deck editor always passes a
        /// non-nil deck id.
        case create(deckId: UUID?)
        case edit(CardSnapshot)
    }

    @Published var frontText: String
    @Published var backText: String
    @Published private(set) var frontError: CardTextError?
    @Published private(set) var backError: CardTextError?

    let mode: Mode

    private let store: CardStore
    private let clock: () -> Date

    init(
        mode: Mode,
        store: CardStore,
        clock: @escaping () -> Date = Date.init
    ) {
        self.mode = mode
        self.store = store
        self.clock = clock

        switch mode {
        case .create:
            self.frontText = ""
            self.backText = ""
        case .edit(let snapshot):
            self.frontText = snapshot.frontText
            self.backText = snapshot.backText
        }
        self.frontError = nil
        self.backError = nil
    }

    /// Applies the two non-empty rules independently to the two fields and
    /// publishes both errors. Not short-circuited — both errors may be set
    /// concurrently when both fields are trimmed-empty.
    func validate() {
        frontError = trimmed(frontText).isEmpty ? .missingFront : nil
        backError  = trimmed(backText).isEmpty  ? .missingBack  : nil
    }

    /// Re-validates and submits. Throws `CardTextError` on validation failure
    /// (and also sets the corresponding `@Published` error channel). Throws
    /// whatever the store throws on persistence failure.
    ///
    /// In `.create` mode, returns the snapshot from `store.create(...)`. In
    /// `.edit` mode, calls `store.update(...)` and re-reads the updated
    /// snapshot via `store.fetchAll()` to return it (since `update` returns
    /// Void per the `CardStore` protocol).
    @discardableResult
    func submit() throws -> CardSnapshot {
        validate()
        if let frontError {
            throw frontError
        }
        if let backError {
            throw backError
        }

        switch mode {
        case .create(let deckId):
            let deckIds: Set<UUID> = deckId.map { [$0] } ?? []
            return try store.create(
                frontText: frontText,
                backText: backText,
                deckIds: deckIds
            )
        case .edit(let snapshot):
            try store.update(
                id: snapshot.id,
                frontText: frontText,
                backText: backText
            )
            let all = try store.fetchAll()
            guard let updated = all.first(where: { $0.id == snapshot.id }) else {
                // The card must exist after a successful update. If it's
                // missing, surface that as a persistence failure — tests do
                // not exercise this branch.
                let underlying = NSError(
                    domain: "CardEditorViewModel",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Card not found after update"]
                )
                throw CardStoreError.persistenceFailed(underlying: underlying)
            }
            return updated
        }
    }

    /// Deletes the card. No-op in `.create` mode; in `.edit` mode calls
    /// `store.delete(id:)` and surfaces store errors to the caller.
    func delete() throws {
        switch mode {
        case .create:
            return
        case .edit(let snapshot):
            try store.delete(id: snapshot.id)
        }
    }

    // MARK: - Private helpers

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
