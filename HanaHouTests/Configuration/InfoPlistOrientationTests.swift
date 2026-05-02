//
//  InfoPlistOrientationTests.swift
//  HanaHouTests
//
//  Feature: deck-management
//  Validates that the app is locked to portrait orientation via a single
//  point of change (the app target's INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad
//  build setting), so landscape support can be enabled later by editing one key.
//
//  Validates requirements: 7.2, 7.3, 7.4, 7.5
//

import XCTest
@testable import HanaHou

final class InfoPlistOrientationTests: XCTestCase {

    /// Locates the HanaHou.app bundle within the test host so we read the
    /// generated Info.plist produced from `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad`.
    private func hanaHouBundle() -> Bundle {
        // `Bundle(for:)` of a symbol in the app module returns the app bundle
        // when tests are hosted by the app.
        Bundle(for: DeckEditorViewModel.self)
    }

    /// Extracts the orientation array from the Info.plist, preferring the
    /// iPad-specific key when present.
    private func portraitOrientations() -> [String] {
        let bundle = hanaHouBundle()
        if let ipad = bundle.object(forInfoDictionaryKey: "UISupportedInterfaceOrientations~ipad") as? [String] {
            return ipad
        }
        if let generic = bundle.object(forInfoDictionaryKey: "UISupportedInterfaceOrientations") as? [String] {
            return generic
        }
        return []
    }

    func test_supportedOrientations_containsOnlyPortraitVariants() {
        let orientations = portraitOrientations()

        XCTAssertFalse(orientations.isEmpty, "UISupportedInterfaceOrientations must be configured in the app's Info.plist")

        let allowed: Set<String> = [
            "UIInterfaceOrientationPortrait",
            "UIInterfaceOrientationPortraitUpsideDown"
        ]

        let configured = Set(orientations)
        XCTAssertTrue(
            configured.isSubset(of: allowed),
            "App must lock to portrait variants only; found: \(orientations.sorted())"
        )
    }

    func test_supportedOrientations_excludesLandscape() {
        let orientations = Set(portraitOrientations())

        XCTAssertFalse(
            orientations.contains("UIInterfaceOrientationLandscapeLeft"),
            "Landscape rotation must be suppressed in P0 (Req 7.4)"
        )
        XCTAssertFalse(
            orientations.contains("UIInterfaceOrientationLandscapeRight"),
            "Landscape rotation must be suppressed in P0 (Req 7.4)"
        )
    }

    func test_supportedOrientations_includesPortrait() {
        let orientations = Set(portraitOrientations())

        XCTAssertTrue(
            orientations.contains("UIInterfaceOrientationPortrait"),
            "Portrait must be supported (Req 7.2)"
        )
    }
}
