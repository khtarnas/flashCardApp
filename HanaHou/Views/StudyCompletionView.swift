//
//  StudyCompletionView.swift
//  HanaHou
//
//  Feature: study-mode
//

import SwiftUI

/// Displayed after every card in the study session has been graded
/// (Req 6 AC 1). P0 shows a single "finished" message and a "Return
/// Home" button that dismisses the study surface and pops the
/// navigation stack to the Deck list root (Req 6 AC 3, 6 AC 5 per
/// D010).
///
/// **No statistics, no grade counts, no history** (Req 6 AC 4 per
/// D010 — the summary screen is a future feature). The view is
/// deliberately stateless: it holds no reference to the view model.
/// It takes the deck name for display and a completion callback, and
/// that is all. This makes it trivial to smoke-test in isolation.
///
/// When P1 introduces `StudyEvent` persistence (D039) and the
/// summary screen, this view will evolve to show per-grade counts —
/// but the completion handoff stays the same: one action, returns
/// home.
struct StudyCompletionView: View {
    let deckName: String
    let onReturnHome: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Finished studying \(deckName).")
                .font(.title2)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("StudyCompletionMessage")
            Button("Return Home") {
                onReturnHome()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("StudyReturnHomeButton")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
