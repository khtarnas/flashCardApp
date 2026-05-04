//
//  CardEditorView.swift
//  HanaHou
//
//  Feature: card-management
//

import SwiftUI

/// Unified create/edit UI for a single Card. Parallels `DeckEditorView`:
/// a `Form` with inline field validation, a Cancel/Save toolbar, and a
/// confirmation-gated delete affordance in edit mode only (design §Views).
struct CardEditorView: View {
    @ObservedObject var viewModel: CardEditorViewModel
    let onFinish: () -> Void

    @State private var saveError: Error?
    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            Section("Front") {
                TextField("Front text", text: $viewModel.frontText)
                    .onChange(of: viewModel.frontText) { _, _ in
                        viewModel.validate()
                    }
                if let frontError = viewModel.frontError {
                    Text(Self.message(for: frontError))
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            Section("Back") {
                TextField("Back text", text: $viewModel.backText)
                    .onChange(of: viewModel.backText) { _, _ in
                        viewModel.validate()
                    }
                if let backError = viewModel.backError {
                    Text(Self.message(for: backError))
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            if case .edit = viewModel.mode {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Card", systemImage: "trash")
                    }
                } header: {
                    Text("Danger Zone")
                }
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onFinish)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: attemptSubmit)
                    .disabled(!isSubmittable)
            }
        }
        .confirmationDialog(
            "Delete this card?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: attemptDelete)
            Button("Cancel", role: .cancel) { showDeleteConfirmation = false }
        } message: {
            Text("This can't be undone.")
        }
        .alert(
            "Couldn't save",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            ),
            presenting: saveError
        ) { _ in
            Button("OK", role: .cancel) { saveError = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    // MARK: - Actions

    private func attemptSubmit() {
        do {
            _ = try viewModel.submit()
            onFinish()
        } catch is CardTextError {
            // Already surfaced via frontError / backError — no alert needed.
        } catch {
            saveError = error
        }
    }

    private func attemptDelete() {
        do {
            try viewModel.delete()
            onFinish()
        } catch {
            saveError = error
        }
    }

    // MARK: - Derived state

    private var navigationTitle: String {
        switch viewModel.mode {
        case .create: return "New Card"
        case .edit: return "Edit Card"
        }
    }

    private var isSubmittable: Bool {
        let frontTrimmed = viewModel.frontText.trimmingCharacters(in: .whitespacesAndNewlines)
        let backTrimmed = viewModel.backText.trimmingCharacters(in: .whitespacesAndNewlines)
        return viewModel.frontError == nil
            && viewModel.backError == nil
            && !frontTrimmed.isEmpty
            && !backTrimmed.isEmpty
    }

    // MARK: - Message helper

    /// Human-readable inline message for each `CardTextError` case. Kept on
    /// the view (not the view model) because it's presentation-only.
    static func message(for error: CardTextError) -> String {
        switch error {
        case .missingFront:
            return "Front text is required."
        case .missingBack:
            return "Back text is required."
        }
    }
}
