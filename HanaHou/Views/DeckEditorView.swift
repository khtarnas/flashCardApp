//
//  DeckEditorView.swift
//  HanaHou
//
//  Feature: deck-management
//

import SwiftUI

struct DeckEditorView: View {
    @ObservedObject var viewModel: DeckEditorViewModel
    let onFinish: () -> Void

    @State private var saveError: Error?

    var body: some View {
        Form {
            Section("Name") {
                TextField("e.g. Japanese", text: $viewModel.name)
                    .onChange(of: viewModel.name) { _, _ in
                        viewModel.validateName()
                    }
                if let error = viewModel.nameError {
                    Text(DeckEditorViewModel.message(for: error))
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            Section("Front Language") {
                languagePicker($viewModel.frontLanguage)
            }
            Section("Back Language") {
                languagePicker($viewModel.backLanguage)
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onFinish)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: attemptSubmit)
                    .disabled(viewModel.nameError != nil || viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .alert("Couldn't save", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        ), presenting: saveError) { _ in
            Button("OK", role: .cancel) { saveError = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    private var navigationTitle: String {
        switch viewModel.mode {
        case .create: return "New Deck"
        case .edit: return "Edit Deck"
        }
    }

    private func attemptSubmit() {
        do {
            _ = try viewModel.submit()
            onFinish()
        } catch is DeckNameError {
            // Already surfaced via nameError; no alert needed.
        } catch {
            saveError = error
        }
    }

    @ViewBuilder
    private func languagePicker(_ binding: Binding<Language>) -> some View {
        Picker(selection: binding) {
            ForEach(Language.allCases, id: \.self) { language in
                Text(language.displayName).tag(language)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.menu)
    }
}
