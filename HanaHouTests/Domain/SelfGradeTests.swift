//
//  SelfGradeTests.swift
//  HanaHouTests
//
//  Feature: study-mode
//  Covers requirements: 4.1, 4.6, 9.6, 10.2, 10.3.12
//  Test cases from Req 10 AC 3: 12
//
//  `SelfGrade` is the single point of change for the three self-grade
//  categories (D008, D036). These tests pin its shape — exactly three
//  cases with distinct, non-empty, confidence-oriented labels — so a
//  future rename cannot silently drop or collapse a category, and so
//  the single-source-of-labels guarantee (Req 9 AC 6) remains true.
//
//  The tests intentionally reference the D036 labels verbatim. A future
//  "Test Mode" that swaps in outcome-oriented labels will need its own
//  enum (per D008 "designed to be mutable") — not an in-place label
//  change — precisely because these tests pin the P0 labels.
//

import XCTest
@testable import HanaHou

final class SelfGradeTests: XCTestCase {

    // MARK: - Req 10 AC 3.12 / Req 9 AC 6 / Req 10 AC 2
    //
    // Exactly three cases; each `label` non-empty; all three labels distinct.

    func test_selfGrade_hasThreeCasesWithDistinctNonEmptyLabels() {
        XCTAssertEqual(
            SelfGrade.allCases.count,
            3,
            "SelfGrade must have exactly three cases per D008"
        )

        for grade in SelfGrade.allCases {
            XCTAssertFalse(
                grade.label.isEmpty,
                "SelfGrade.\(grade).label must not be empty"
            )
        }

        let labels = SelfGrade.allCases.map(\.label)
        XCTAssertEqual(
            Set(labels).count,
            labels.count,
            "SelfGrade labels must be pairwise distinct; got \(labels)"
        )
    }

    // MARK: - Req 4 AC 1 per D036
    //
    // The P0 label set is Option A (confidence-oriented): the semantic
    // case names are `.know` / `.close` / `.noIdea`, and their human-
    // readable labels are "I know it" / "I'm close" / "No idea".

    func test_selfGrade_knowCase_hasD036Label() {
        XCTAssertEqual(SelfGrade.know.label, "I know it")
    }

    func test_selfGrade_closeCase_hasD036Label() {
        XCTAssertEqual(SelfGrade.close.label, "I'm close")
    }

    func test_selfGrade_noIdeaCase_hasD036Label() {
        XCTAssertEqual(SelfGrade.noIdea.label, "No idea")
    }

    // MARK: - Req 9 AC 6 / design §Data Models
    //
    // Protocol conformances that the view layer and tests depend on:
    //   - `CaseIterable`  — the study view renders `SelfGrade.allCases`
    //   - `Equatable`     — tests assert on `grades[cardId] == .close`
    //   - raw `String`    — stable on-disk identifier for future P1
    //                       `StudyEvent` persistence per D039

    func test_selfGrade_conformsToCaseIterable() {
        // If `SelfGrade` fails to conform to `CaseIterable`, this line
        // fails to compile — no runtime assertion needed. We still make
        // an assertion to anchor the test's XCTest method.
        let cases: [SelfGrade] = SelfGrade.allCases
        XCTAssertEqual(cases.count, 3)
    }

    func test_selfGrade_conformsToEquatable() {
        // Same reasoning as above: the `==` below only type-checks if
        // `SelfGrade` conforms to `Equatable`.
        XCTAssertTrue(SelfGrade.know == SelfGrade.know)
        XCTAssertFalse(SelfGrade.know == SelfGrade.close)
    }

    func test_selfGrade_exposesStableStringRawValue() {
        // D039 rationale (design §Data Models): the raw value is a
        // stable on-disk identifier independent of the display label,
        // so a future label change does not invalidate persisted data.
        // We assert each case's raw value is non-empty and distinct;
        // we do NOT pin the exact raw string here so that the
        // implementation is free to choose semantic raw values (e.g.,
        // "know", "close", "noIdea") without coupling this test to
        // on-disk schema.
        let raws = SelfGrade.allCases.map(\.rawValue)

        for raw in raws {
            XCTAssertFalse(raw.isEmpty, "SelfGrade raw values must not be empty")
        }
        XCTAssertEqual(
            Set(raws).count,
            raws.count,
            "SelfGrade raw values must be pairwise distinct; got \(raws)"
        )

        // Round-trip: `SelfGrade(rawValue:)` must recover the original case.
        for grade in SelfGrade.allCases {
            XCTAssertEqual(SelfGrade(rawValue: grade.rawValue), grade)
        }
    }

    // MARK: - Single-source-of-labels invariant (Req 4 AC 6, Req 9 AC 6)
    //
    // If anyone adds a hard-coded display string for one of these labels
    // somewhere else in the codebase, D008's "designed to be mutable"
    // guarantee is broken. This test isn't a structural check (we can't
    // grep from inside a unit test), but it makes the invariant's intent
    // explicit and gives a stable anchor for a future test-mode swap.

    func test_selfGrade_allCasesInCaseIterableOrder() {
        // Ordering is the source-file case order. The view renders
        // `SelfGrade.allCases` — this test pins the ordering that users
        // will see top-to-bottom on the three grade buttons.
        XCTAssertEqual(SelfGrade.allCases, [.know, .close, .noIdea])
    }
}
