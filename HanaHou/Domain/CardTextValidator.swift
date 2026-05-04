//
//  CardTextValidator.swift
//  HanaHou
//
//  Feature: card-management
//

import Foundation

/// Validates the text fields of a `CardDraft`.
///
/// Rules (per design §Domain Layer; Glossary "Non-empty text"):
/// - Both fields are trimmed with `.whitespacesAndNewlines` for the
///   emptiness check only; the validator does not mutate the draft.
/// - If the trimmed front text is empty, the result is `.failure(.missingFront)`.
/// - If the trimmed back text is empty, the result is `.failure(.missingBack)`.
/// - Front is checked before back so a single, stable error surfaces per
///   submit; the editor view model re-validates both fields independently
///   so inline messages for each field can be shown concurrently.
/// - On success, the original (untrimmed) draft is returned verbatim.
struct CardTextValidator {

    static func validate(draft: CardDraft) -> Result<CardDraft, CardTextError> {
        if trimmed(draft.frontText).isEmpty {
            return .failure(.missingFront)
        }

        if trimmed(draft.backText).isEmpty {
            return .failure(.missingBack)
        }

        return .success(draft)
    }

    private static func trimmed(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
