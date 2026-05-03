//
//  CardTextError.swift
//  HanaHou
//
//  Feature: card-management
//

import Foundation

/// Validation error for card text fields.
///
/// Two distinct cases — not one combined case — so the editor can surface
/// which field is invalid inline under the corresponding `TextField`
/// (per design §Data Model / §ViewModels). The editor holds two independent
/// `@Published` error channels (`frontError` / `backError`) and may display
/// one, the other, or both messages concurrently when both fields are empty.
///
/// Cases intentionally do not carry the offending text: the editor already
/// has it via its own `@Published` bindings.
enum CardTextError: Error, Equatable {
    /// The card's front text is empty (after trimming whitespace and newlines).
    /// Surfaced by the editor under the "Front" field.
    case missingFront

    /// The card's back text is empty (after trimming whitespace and newlines).
    /// Surfaced by the editor under the "Back" field.
    case missingBack
}
