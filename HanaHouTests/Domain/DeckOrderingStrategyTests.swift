//
//  DeckOrderingStrategyTests.swift
//  HanaHouTests
//
//  Feature: deck-management
//  Covers behaviors: B7 (creation-date ascending with id.uuidString tiebreaker)
//  Validates requirements: 1.6
//

import XCTest
@testable import HanaHou

final class DeckOrderingStrategyTests: XCTestCase {

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

    // MARK: - B7: Creation-date ascending ordering with id.uuidString tiebreaker
    // Requirements: 1.6

    func test_emptyInput_returnsEmpty() {
        let strategy = CreationDateAscendingOrdering()

        let result = strategy.order([])

        XCTAssertEqual(result, [])
    }

    func test_singleInput_returnsSingleton() {
        let strategy = CreationDateAscendingOrdering()
        let only = makeDeck(createdAt: Date(timeIntervalSince1970: 1_000))

        let result = strategy.order([only])

        XCTAssertEqual(result, [only])
    }

    func test_distinctCreationDates_sortedAscending() {
        let strategy = CreationDateAscendingOrdering()
        // 2024-01-01, 2024-01-15, 2024-02-01 as deterministic timestamps
        let d1 = makeDeck(createdAt: Date(timeIntervalSince1970: 1_704_067_200)) // 2024-01-01
        let d2 = makeDeck(createdAt: Date(timeIntervalSince1970: 1_705_276_800)) // 2024-01-15
        let d3 = makeDeck(createdAt: Date(timeIntervalSince1970: 1_706_745_600)) // 2024-02-01

        let result = strategy.order([d2, d3, d1])

        XCTAssertEqual(result.map(\.id), [d1.id, d2.id, d3.id])
    }

    func test_equalCreationDates_tiebreakerByIdUuidString() {
        let strategy = CreationDateAscendingOrdering()
        let sharedDate = Date(timeIntervalSince1970: 1_704_067_200)
        // "...0001".uuidString < "...0002".uuidString lexicographically
        let idOne = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let idTwo = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let deckOne = makeDeck(id: idOne, createdAt: sharedDate)
        let deckTwo = makeDeck(id: idTwo, createdAt: sharedDate)

        // Pass in reverse order to confirm the tiebreaker actually sorts them
        let result = strategy.order([deckTwo, deckOne])

        XCTAssertEqual(result.map(\.id), [idOne, idTwo])
    }

    func test_mixedEqualAndDistinctDates_ordersCorrectly() {
        let strategy = CreationDateAscendingOrdering()
        let t0 = Date(timeIntervalSince1970: 1_000)
        let t1 = Date(timeIntervalSince1970: 2_000)
        let t2 = Date(timeIntervalSince1970: 3_000)
        // a and b share t1; a.id lexicographically before b.id
        let aId = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
        let bId = UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!
        let cId = UUID(uuidString: "00000000-0000-0000-0000-0000000000CC")!
        let dId = UUID(uuidString: "00000000-0000-0000-0000-0000000000DD")!
        let a = makeDeck(id: aId, createdAt: t1)
        let b = makeDeck(id: bId, createdAt: t1)
        let c = makeDeck(id: cId, createdAt: t0)
        let d = makeDeck(id: dId, createdAt: t2)

        let result = strategy.order([b, d, a, c])

        XCTAssertEqual(result.map(\.id), [cId, aId, bId, dId])
    }

    func test_orderingIsPureAndDeterministic() {
        let strategy = CreationDateAscendingOrdering()
        let sharedDate = Date(timeIntervalSince1970: 5_000)
        let distinctDate = Date(timeIntervalSince1970: 10_000)
        let idA = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let idB = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let idC = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let input = [
            makeDeck(id: idB, createdAt: sharedDate),
            makeDeck(id: idC, createdAt: distinctDate),
            makeDeck(id: idA, createdAt: sharedDate)
        ]

        let first = strategy.order(input)
        let second = strategy.order(input)

        XCTAssertEqual(first, second)
    }

    func test_protocolConformance() {
        let strategy: DeckOrderingStrategy = CreationDateAscendingOrdering()

        XCTAssertEqual(strategy.order([]).count, 0)
    }
}
