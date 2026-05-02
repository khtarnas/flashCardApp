//
//  DeckNameValidatorTests.swift
//  HanaHouTests
//
//  Feature: deck-management
//  Covers behaviors: B1 (empty), B2 (reserved), B3 (duplicate with edit-mode self-exclusion)
//  Validates requirements: 2.4, 2.5, 2.6, 3.3, 3.4, 3.5, 5.1, 5.2, 5.3, 5.4, 5.6, 6.2, 6.3
//

import XCTest
@testable import HanaHou

final class DeckNameValidatorTests: XCTestCase {

    // MARK: - Helpers

    private func makeDeck(id: UUID = UUID(), name: String) -> DeckSnapshot {
        DeckSnapshot(
            id: id,
            name: name,
            frontLanguage: .english,
            backLanguage: .japanese,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    // MARK: - B1: Empty / whitespace names → .empty
    // Requirements: 2.4, 3.3, 5.1, 5.4

    func test_emptyOrWhitespaceNames_rejectedAsEmpty() {
        let whitespaceInputs = [
            "",
            "   ",
            "\t",
            "\n",
            " \t\n "
        ]

        for input in whitespaceInputs {
            // Create mode
            let createResult = DeckNameValidator.validate(
                name: input,
                against: [],
                editingDeckId: nil
            )
            switch createResult {
            case .failure(.empty):
                break // expected
            default:
                XCTFail("Expected .failure(.empty) for create mode with input \(String(reflecting: input)), got \(createResult)")
            }

            // Edit mode (editingDeckId doesn't match any stored deck, since store is empty)
            let editResult = DeckNameValidator.validate(
                name: input,
                against: [],
                editingDeckId: UUID()
            )
            switch editResult {
            case .failure(.empty):
                break // expected
            default:
                XCTFail("Expected .failure(.empty) for edit mode with input \(String(reflecting: input)), got \(editResult)")
            }
        }
    }

    // MARK: - B2: Reserved-name variants → .reserved
    // Requirements: 2.6, 3.5, 5.3, 5.4, 5.6, 6.3

    func test_reservedNameVariants_rejectedAsReserved() {
        let reservedInputs = [
            "All Cards",
            "all cards",
            "ALL CARDS",
            "  All Cards  ",
            "aLL cArDs",
            "\tAll Cards\n"
        ]

        for input in reservedInputs {
            // Create mode
            let createResult = DeckNameValidator.validate(
                name: input,
                against: [],
                editingDeckId: nil
            )
            switch createResult {
            case .failure(.reserved(let name)):
                XCTAssertEqual(name, input, "Reserved error should carry the original input name (pre-trim) for create mode, input: \(String(reflecting: input))")
            default:
                XCTFail("Expected .failure(.reserved) for create mode with input \(String(reflecting: input)), got \(createResult)")
            }

            // Edit mode (with a non-matching editingDeckId)
            let editResult = DeckNameValidator.validate(
                name: input,
                against: [],
                editingDeckId: UUID()
            )
            switch editResult {
            case .failure(.reserved(let name)):
                XCTAssertEqual(name, input, "Reserved error should carry the original input name (pre-trim) for edit mode, input: \(String(reflecting: input))")
            default:
                XCTFail("Expected .failure(.reserved) for edit mode with input \(String(reflecting: input)), got \(editResult)")
            }
        }
    }

    // MARK: - B3: Duplicate names → .duplicate, with edit-mode self-exclusion
    // Requirements: 2.5, 3.4, 5.2, 5.4, 6.2

    func test_createMode_exactDuplicate_rejected() {
        let existing = makeDeck(name: "Japanese")

        let result = DeckNameValidator.validate(
            name: "Japanese",
            against: [existing],
            editingDeckId: nil
        )

        switch result {
        case .failure(.duplicate(let name)):
            XCTAssertEqual(name, "Japanese")
        default:
            XCTFail("Expected .failure(.duplicate(name: \"Japanese\")), got \(result)")
        }
    }

    func test_createMode_whitespaceVariantOfDuplicate_rejected() {
        let existing = makeDeck(name: "Japanese")

        let result = DeckNameValidator.validate(
            name: "  Japanese  ",
            against: [existing],
            editingDeckId: nil
        )

        switch result {
        case .failure(.duplicate(let name)):
            XCTAssertEqual(name, "  Japanese  ", "Duplicate error should carry the original input name (pre-trim)")
        default:
            XCTFail("Expected .failure(.duplicate(name: \"  Japanese  \")), got \(result)")
        }
    }

    func test_createMode_caseVariantIsNotDuplicate_succeeds() {
        let existing = makeDeck(name: "Japanese")

        let result = DeckNameValidator.validate(
            name: "japanese",
            against: [existing],
            editingDeckId: nil
        )

        switch result {
        case .success(let name):
            XCTAssertEqual(name, "japanese")
        default:
            XCTFail("Expected .success(\"japanese\") — case-sensitive duplicate comparison, got \(result)")
        }
    }

    func test_editMode_sameName_isNotDuplicateAgainstItself() {
        let deckId = UUID()
        let existing = makeDeck(id: deckId, name: "Japanese")

        let result = DeckNameValidator.validate(
            name: "Japanese",
            against: [existing],
            editingDeckId: deckId
        )

        switch result {
        case .success(let name):
            XCTAssertEqual(name, "Japanese")
        default:
            XCTFail("Expected .success(\"Japanese\") — edit mode excludes the target deck from duplicate check, got \(result)")
        }
    }

    func test_editMode_sameName_butDifferentId_isDuplicate() {
        let deckD = makeDeck(id: UUID(), name: "Japanese")
        let deckEId = UUID()
        let deckE = makeDeck(id: deckEId, name: "Korean")

        let result = DeckNameValidator.validate(
            name: "Japanese",
            against: [deckD, deckE],
            editingDeckId: deckEId
        )

        switch result {
        case .failure(.duplicate(let name)):
            XCTAssertEqual(name, "Japanese")
        default:
            XCTFail("Expected .failure(.duplicate(name: \"Japanese\")) — renaming E to a name owned by D is a duplicate, got \(result)")
        }
    }

    func test_editMode_newUniqueName_succeeds() {
        let deckId = UUID()
        let existing = makeDeck(id: deckId, name: "Japanese")

        let result = DeckNameValidator.validate(
            name: "French",
            against: [existing],
            editingDeckId: deckId
        )

        switch result {
        case .success(let name):
            XCTAssertEqual(name, "French")
        default:
            XCTFail("Expected .success(\"French\"), got \(result)")
        }
    }

    // MARK: - Validity sanity-check tests

    func test_validName_emptyStore_succeeds() {
        let result = DeckNameValidator.validate(
            name: "Japanese",
            against: [],
            editingDeckId: nil
        )

        switch result {
        case .success(let name):
            XCTAssertEqual(name, "Japanese")
        default:
            XCTFail("Expected .success(\"Japanese\"), got \(result)")
        }
    }

    func test_successCasePreservesOriginalSpacing() {
        let result = DeckNameValidator.validate(
            name: "  Japanese  ",
            against: [],
            editingDeckId: nil
        )

        switch result {
        case .success(let name):
            XCTAssertEqual(name, "  Japanese  ", "The validator does NOT trim for the success case — the store preserves user spacing (design §3)")
        default:
            XCTFail("Expected .success(\"  Japanese  \") with preserved spacing, got \(result)")
        }
    }
}
