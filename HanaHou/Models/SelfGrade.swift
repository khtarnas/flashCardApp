//
//  SelfGrade.swift
//  HanaHou
//
//  Feature: study-mode
//

import Foundation

/// The three self-grade categories the user can assign to a Card in
/// study mode. Per D008, the set of categories is **designed to be
/// mutable** — but this enum is the single point of change. Views, view
/// models, and tests render labels via `SelfGrade.label`; none hard-codes
/// the display string (Req 4 AC 6, Req 9 AC 6).
///
/// The P0 labels are confidence-oriented (D036 / Option A): the user
/// reports what they *knew*, not what they *got right or wrong*. A
/// future "Test Mode" can introduce its own outcome-oriented enum
/// (e.g., "Got it", "Close", "Missed") without touching this file —
/// that future enum will be the single point of change for Test Mode's
/// labels, in the same way this one is the single point of change for
/// Free Study's labels.
///
/// - Note: The `String` raw value is present for future-proofing. When
///   P1 introduces `StudyEvent` persistence (D039), the raw value is a
///   stable on-disk identifier independent of the display label, so a
///   label change will not invalidate persisted data. P0 does not
///   persist anything; choosing a stable raw representation now costs
///   nothing.
/// - Note: `Equatable` conformance is used by tests to assert on
///   `grades[cardId] == .close`; `CaseIterable` is used by the study
///   view to render `SelfGrade.allCases` without a hand-kept parallel
///   list (Req 9 AC 6).
enum SelfGrade: String, Equatable, CaseIterable {

    /// "I know it" — the user confidently recalled the answer.
    case know

    /// "I'm close" — partial recall; some uncertainty.
    case close

    /// "No idea" — the user could not recall the answer.
    case noIdea

    /// Human-readable display label. **The single point of change** for
    /// the three P0 study-mode categories (D008, D036, Req 4 AC 6,
    /// Req 9 AC 6). Renaming here propagates to every view, button, and
    /// test assertion that surfaces the category to the user.
    var label: String {
        switch self {
        case .know:   return "I know it"
        case .close:  return "I'm close"
        case .noIdea: return "No idea"
        }
    }
}
