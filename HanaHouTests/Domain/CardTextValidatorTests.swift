//
//  CardTextValidatorTests.swift
//  HanaHouTests
//
//  Feature: card-management
//  Covers behaviors: C1, C2
//  Validates requirements: 1.3, 1.4, 3.3, 3.4; Glossary "Non-empty text"
//

import XCTest
@testable import HanaHou

final class CardTextValidatorTests: XCTestCase {

    // MARK: - Helpers

    private func validate(
        front: String,
        back: String
    ) -> Result<CardDraft, CardTextError> {
        let draft = CardDraft(frontText: front, backText: back)
        return CardTextValidator.validate(draft: draft)
    }

    // MARK: - Success cases

    /// A draft with non-trimmed-empty front and back returns `.success(draft)`,
    /// and the returned draft equals the input verbatim.
    /// Validates: Requirements 1.3, 1.4, 3.3, 3.4
    func test_validate_success_withNonEmptyFrontAndBack() {
        let draft = CardDraft(frontText: "hi", backText: "hello")

        let result = CardTextValidator.validate(draft: draft)

        XCTAssertEqual(result, .success(draft))
    }

    /// The validator trims only for the emptiness check — it does not mutate
    /// the draft. A draft with `" hi "` / `" hello "` succeeds and preserves
    /// the untrimmed strings on the returned `CardDraft`.
    /// Validates: Requirements 1.3, 1.4, 3.3, 3.4; Glossary "Non-empty text"
    func test_validate_success_preservesNonTrimmedText() {
        let draft = CardDraft(frontText: " hi ", backText: " hello ")

        let result = CardTextValidator.validate(draft: draft)

        XCTAssertEqual(result, .success(draft))
    }

    // MARK: - C1: Empty front text → .missingFront
    // Requirements: 1.3, 3.3; Glossary "Non-empty text"

    func test_validate_missingFront_emptyString() {
        let result = validate(front: "", back: "hello")
        XCTAssertEqual(result, .failure(.missingFront))
    }

    func test_validate_missingFront_whitespaceOnly() {
        let result = validate(front: "   ", back: "hello")
        XCTAssertEqual(result, .failure(.missingFront))
    }

    func test_validate_missingFront_tabOnly() {
        let result = validate(front: "\t", back: "hello")
        XCTAssertEqual(result, .failure(.missingFront))
    }

    func test_validate_missingFront_newlineOnly() {
        let result = validate(front: "\n", back: "hello")
        XCTAssertEqual(result, .failure(.missingFront))
    }

    func test_validate_missingFront_mixedWhitespace() {
        let result = validate(front: " \t\n ", back: "hello")
        XCTAssertEqual(result, .failure(.missingFront))
    }

    // MARK: - C2: Empty back text → .missingBack
    // Requirements: 1.4, 3.4; Glossary "Non-empty text"

    func test_validate_missingBack_emptyString() {
        let result = validate(front: "hi", back: "")
        XCTAssertEqual(result, .failure(.missingBack))
    }

    func test_validate_missingBack_whitespaceOnly() {
        let result = validate(front: "hi", back: "   ")
        XCTAssertEqual(result, .failure(.missingBack))
    }

    func test_validate_missingBack_tabOnly() {
        let result = validate(front: "hi", back: "\t")
        XCTAssertEqual(result, .failure(.missingBack))
    }

    func test_validate_missingBack_newlineOnly() {
        let result = validate(front: "hi", back: "\n")
        XCTAssertEqual(result, .failure(.missingBack))
    }

    func test_validate_missingBack_mixedWhitespace() {
        let result = validate(front: "hi", back: " \t\n ")
        XCTAssertEqual(result, .failure(.missingBack))
    }

    // MARK: - C2: Front priority when both are empty
    // Per design §Domain Layer, front is checked before back, so when both
    // are trimmed-empty the validator returns `.missingFront`.
    // Requirements: 1.3, 1.4, 3.3, 3.4

    func test_validate_bothEmpty_frontPriority() {
        let whitespaceInputs = [
            "",
            "   ",
            "\t",
            "\n",
            " \t\n "
        ]

        for front in whitespaceInputs {
            for back in whitespaceInputs {
                let result = validate(front: front, back: back)
                XCTAssertEqual(
                    result,
                    .failure(.missingFront),
                    "Expected .failure(.missingFront) for front=\(String(reflecting: front)) back=\(String(reflecting: back))"
                )
            }
        }
    }
}
