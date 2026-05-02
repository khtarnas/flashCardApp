//
//  DeckListComposerTests.swift
//  HanaHouTests
//
//  Feature: deck-management
//  Covers behaviors: B8 (exactly one .allCards at index 0, strategy-independent), B9 (user-deck subsequence = strategy.order(userDecks))
//  Validates requirements: 1.1, 1.3, 1.4, 1.5, 8.1
//

import XCTest
@testable import HanaHou

private struct ReverseOrderingStub: DeckOrderingStrategy {
    func order(_ decks: [DeckSnapshot]) -> [DeckSnapshot] {
        decks.reversed()
    }
}

final class DeckListComposerTests: XCTestCase {

    // MARK: - Helpers

    private func makeDeck(
        id: UUID = UUID(),
        name: String = "Deck",
        createdAt: Date
    ) -> DeckSnapshot {
        DeckSnapshot(
            id: id,
            name: name,
            frontLanguage: .english,
            backLanguage: .japanese,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    private func deckIds(_ items: [DeckListItem]) -> [UUID] {
        items.compactMap { item in
            if case .deck(let snapshot) = item { return snapshot.id }
            return nil
        }
    }

    // MARK: - B8: .allCards invariant
    // Requirements: 1.3, 1.4, 8.1

    func test_emptyInput_containsOnlyAllCardsAtIndex0() {
        let result = DeckListComposer.compose(
            userDecks: [],
            strategy: CreationDateAscendingOrdering()
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, .allCards)
    }

    func test_singleUserDeck_allCardsAtIndex0_deckAtIndex1() {
        let deck = makeDeck(createdAt: Date(timeIntervalSince1970: 1_000))

        let result = DeckListComposer.compose(
            userDecks: [deck],
            strategy: CreationDateAscendingOrdering()
        )

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].id, .allCards)
        XCTAssertEqual(result[1].id, .deck(deck.id))
    }

    func test_exactlyOneAllCardsAcrossStrategies() {
        let d1 = makeDeck(createdAt: Date(timeIntervalSince1970: 1_000))
        let d2 = makeDeck(createdAt: Date(timeIntervalSince1970: 2_000))
        let d3 = makeDeck(createdAt: Date(timeIntervalSince1970: 3_000))
        let input = [d2, d3, d1]

        let p0Result = DeckListComposer.compose(
            userDecks: input,
            strategy: CreationDateAscendingOrdering()
        )
        let stubResult = DeckListComposer.compose(
            userDecks: input,
            strategy: ReverseOrderingStub()
        )

        XCTAssertEqual(p0Result.filter { $0.id == .allCards }.count, 1)
        XCTAssertEqual(p0Result.first?.id, .allCards)
        XCTAssertEqual(stubResult.filter { $0.id == .allCards }.count, 1)
        XCTAssertEqual(stubResult.first?.id, .allCards)
    }

    func test_allCardsPositionInvariantToStrategyChoice() {
        let d1 = makeDeck(createdAt: Date(timeIntervalSince1970: 1_000))
        let d2 = makeDeck(createdAt: Date(timeIntervalSince1970: 2_000))
        let d3 = makeDeck(createdAt: Date(timeIntervalSince1970: 3_000))
        let input = [d2, d3, d1]

        let p0Result = DeckListComposer.compose(
            userDecks: input,
            strategy: CreationDateAscendingOrdering()
        )
        let stubResult = DeckListComposer.compose(
            userDecks: input,
            strategy: ReverseOrderingStub()
        )

        XCTAssertEqual(p0Result[0].id, .allCards)
        XCTAssertEqual(stubResult[0].id, .allCards)
    }

    // MARK: - B9: User-deck subsequence equals strategy.order(userDecks)
    // Requirements: 1.1, 1.5

    func test_userDeckSubsequenceEqualsStrategyOutput_P0Strategy() {
        let d1 = makeDeck(createdAt: Date(timeIntervalSince1970: 1_000))
        let d2 = makeDeck(createdAt: Date(timeIntervalSince1970: 2_000))
        let d3 = makeDeck(createdAt: Date(timeIntervalSince1970: 3_000))
        let input = [d2, d3, d1]

        let result = DeckListComposer.compose(
            userDecks: input,
            strategy: CreationDateAscendingOrdering()
        )

        let tail = Array(result.dropFirst())
        let expectedIds = CreationDateAscendingOrdering().order(input).map(\.id)
        XCTAssertEqual(deckIds(tail), expectedIds)
    }

    func test_userDeckSubsequenceEqualsStrategyOutput_reverseStub() {
        let d1 = makeDeck(createdAt: Date(timeIntervalSince1970: 1_000))
        let d2 = makeDeck(createdAt: Date(timeIntervalSince1970: 2_000))
        let d3 = makeDeck(createdAt: Date(timeIntervalSince1970: 3_000))
        let input = [d2, d3, d1]

        let result = DeckListComposer.compose(
            userDecks: input,
            strategy: ReverseOrderingStub()
        )

        let tail = Array(result.dropFirst())
        let expectedIds = input.reversed().map(\.id)
        XCTAssertEqual(deckIds(tail), expectedIds)
    }
}
