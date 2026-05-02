//
//  DeckEditorViewModel.swift
//  HanaHou
//
//  Feature: deck-management
//

import Foundation
import Combine

@MainActor
final class DeckEditorViewModel: ObservableObject {

    enum Mode: Equatable {
        case create
        case edit(DeckSnapshot)
    }

    @Published var name: String
    @Published var frontLanguage: Language
    @Published var backLanguage: Language
    @Published private(set) var nameError: DeckNameError?

    let mode: Mode

    private let store: DeckStore
    private let clock: () -> Date

    init(
        mode: Mode,
        store: DeckStore,
        clock: @escaping () -> Date = Date.init
    ) {
        self.mode = mode
        self.store = store
        self.clock = clock

        switch mode {
        case .create:
            self.name = ""
            self.frontLanguage = .english
            self.backLanguage = .japanese
        case .edit(let snapshot):
            self.name = snapshot.name
            self.frontLanguage = snapshot.frontLanguage
            self.backLanguage = snapshot.backLanguage
        }
        self.nameError = nil
    }

    /// Re-runs the name validator against the store's current decks.
    /// Updates `nameError`. Does not throw — swallows the Result into state.
    func validateName() {
        switch runValidation() {
        case .failure(let error):
            nameError = error
        case .success:
            nameError = nil
        }
    }

    /// Submits the current draft.
    /// On validation failure, throws the DeckNameError (and also sets `nameError`).
    /// On persistence failure, throws whatever the store throws (typically DeckStoreError).
    @discardableResult
    func submit() throws -> DeckSnapshot {
        switch runValidation() {
        case .failure(let error):
            nameError = error
            throw error
        case .success:
            nameError = nil
        }

        let draft = DeckDraft(
            name: name,
            frontLanguage: frontLanguage,
            backLanguage: backLanguage
        )

        switch mode {
        case .create:
            return try store.create(draft)
        case .edit(let snapshot):
            return try store.update(id: snapshot.id, with: draft)
        }
    }

    /// Human-readable message for a given name error. Used by the view's inline label.
    static func message(for error: DeckNameError) -> String {
        switch error {
        case .empty:
            return "Name is required."
        case .reserved(let name):
            return "\"\(trimmed(name))\" is reserved and cannot be used."
        case .duplicate(let name):
            return "A deck named \"\(trimmed(name))\" already exists."
        }
    }

    // MARK: - Private helpers

    private func runValidation() -> Result<String, DeckNameError> {
        let decks = (try? store.fetchAll()) ?? []
        let editingDeckId: UUID?
        switch mode {
        case .create:
            editingDeckId = nil
        case .edit(let snapshot):
            editingDeckId = snapshot.id
        }
        return DeckNameValidator.validate(
            name: name,
            against: decks,
            editingDeckId: editingDeckId
        )
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
