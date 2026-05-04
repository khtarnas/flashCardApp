//
//  StudyView.swift
//  HanaHou
//
//  Feature: study-mode
//

import SwiftUI

/// The P0 study surface. A single SwiftUI view that renders different
/// content based on `viewModel.session.phase` — all three active
/// surfaces (front, back, empty-deck) plus the completion surface
/// live in the same view so the transition between them is just a
/// phase change in the view model, not a separate navigation push.
///
/// Navigation callbacks:
/// - `onExit` pops one level back to `CardListView` (Req 7 AC 3).
/// - `onReturnHome` pops to the root of the navigation stack, i.e.,
///   the Deck list (Req 6 AC 5).
///
/// The Exit toolbar affordance is visible only in `.frontRevealed` and
/// `.backRevealed` (Req 7 AC 1). The empty-state view offers its own
/// "Back to deck" button (Req 1 AC 10). Completion is presented as
/// `StudyCompletionView` inline, not as a separate navigation
/// destination (Req 6 AC 1).
///
/// Orientation inherits the app-wide Info.plist portrait lock
/// (D014/D028) — no study-side override (Req 8 AC 3, 8 AC 4).
struct StudyView: View {
    let deck: DeckSnapshot
    @StateObject var viewModel: StudySessionViewModel
    let onExit: () -> Void
    let onReturnHome: () -> Void

    var body: some View {
        content
            .navigationTitle(deck.name)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if showsExitButton {
                        Button("Exit") {
                            viewModel.exit()
                            onExit()
                        }
                        .accessibilityIdentifier("StudyExitButton")
                    }
                }
            }
            .alert(
                "Couldn't load cards",
                isPresented: Binding(
                    get: { viewModel.loadError != nil },
                    set: { if !$0 { viewModel.loadError = nil } }
                ),
                presenting: viewModel.loadError
            ) { _ in
                Button("OK", role: .cancel) {
                    viewModel.loadError = nil
                    onExit()
                }
            } message: { error in
                Text(error.localizedDescription)
            }
    }

    // MARK: - Phase dispatch

    @ViewBuilder
    private var content: some View {
        switch viewModel.session.phase {
        case .frontRevealed, .backRevealed:
            activeSessionContent
        case .completed:
            StudyCompletionView(deckName: deck.name) {
                viewModel.returnHome()
                onReturnHome()
            }
        case .emptyDeck:
            emptyDeckContent
        }
    }

    private var showsExitButton: Bool {
        switch viewModel.session.phase {
        case .frontRevealed, .backRevealed: return true
        case .completed, .emptyDeck:        return false
        }
    }

    // MARK: - Active session (.frontRevealed / .backRevealed)

    @ViewBuilder
    private var activeSessionContent: some View {
        if let card = viewModel.currentCard {
            VStack(spacing: 24) {
                progressLabel(card: card)
                cardFace(card: card)
                Spacer()
                actionArea(card: card)
            }
            .padding(24)
        } else {
            // Defensive: .frontRevealed / .backRevealed with no current
            // card projection means the view model's invariants were
            // violated (position out of range). Render a neutral state.
            Color.clear
        }
    }

    private func progressLabel(card: CurrentCardView) -> some View {
        // Req 2 AC 5 — e.g., "3 of 10". Rendered in both .frontRevealed
        // and .backRevealed so the user always knows where they are.
        Text("\(card.position + 1) of \(card.total)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("StudyProgressLabel")
    }

    @ViewBuilder
    private func cardFace(card: CurrentCardView) -> some View {
        VStack(spacing: 16) {
            Text(card.frontText)
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("StudyFrontText")

            if card.phase == .backRevealed {
                Divider()
                Text(card.backText)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("StudyBackText")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func actionArea(card: CurrentCardView) -> some View {
        switch card.phase {
        case .frontRevealed:
            // Req 2 AC 4 — reveal affordance. Req 2 AC 3 — no grade buttons here.
            Button {
                viewModel.flip()
            } label: {
                Text("Show Back")
                    .font(.title3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("StudyShowBackButton")

        case .backRevealed:
            // Req 3 AC 3, Req 4 AC 1, Req 4 AC 2 — three grade buttons,
            // one per SelfGrade case, labels sourced from SelfGrade.label
            // (the single point of change per D008/D036).
            VStack(spacing: 12) {
                ForEach(SelfGrade.allCases, id: \.self) { grade in
                    Button {
                        viewModel.grade(grade)
                    } label: {
                        Text(grade.label)
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(studyGradeIdentifier(for: grade))
                }
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Empty deck (.emptyDeck)

    @ViewBuilder
    private var emptyDeckContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("This deck has no cards to study yet.")
                .font(.headline)
                .multilineTextAlignment(.center)
            Button("Back to deck") {
                viewModel.exit()
                onExit()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("StudyEmptyDeckBackButton")
        }
        .padding()
    }

    // MARK: - Accessibility identifiers for the three grade buttons

    private func studyGradeIdentifier(for grade: SelfGrade) -> String {
        switch grade {
        case .know:   return "StudyGradeKnowButton"
        case .close:  return "StudyGradeCloseButton"
        case .noIdea: return "StudyGradeNoIdeaButton"
        }
    }
}
