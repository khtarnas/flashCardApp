//
//  DeckNameValidator.swift
//  HanaHou
//
//  Feature: deck-management
//

import Foundation

struct DeckNameValidator {

    private static let reservedNames = ["All Cards"]

    static func validate(
        name proposedName: String,
        against existingDecks: [DeckSnapshot],
        editingDeckId: UUID? = nil
    ) -> Result<String, DeckNameError> {
        let trimmed = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return .failure(.empty)
        }

        for reserved in reservedNames {
            if trimmed.caseInsensitiveCompare(reserved) == .orderedSame {
                return .failure(.reserved(name: proposedName))
            }
        }

        for deck in existingDecks where deck.id != editingDeckId {
            let storedTrimmed = deck.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if storedTrimmed == trimmed {
                return .failure(.duplicate(name: proposedName))
            }
        }

        return .success(proposedName)
    }
}
