//
//  CardOrderingStrategyTests.swift
//  HanaHouTests
//
//  Feature: card-management
//  Covers behaviors: C8
//  Validates requirements: 2.3, 5.4
//

import XCTest
@testable import HanaHou

final class CardOrderingStrategyTests: XCTestCase {

    // MARK: - Helpers

    private func card(
        id: UUID,
        createdAt: Date,
        updatedAt: Date? = nil,
        deckIds: Set<UUID> = []
    ) -> CardSnapshot {
        CardSnapshot(
            id: id,
            frontText: "front",
            backText: "back",
            createdAt: createdAt,
            updatedAt: updatedAt ?? createdAt,
            deckIds: deckIds
        )
    }

    // MARK: - C8: createdAt ascending with id.uuidString tiebreaker
    // Requirements: 2.3, 5.4

    func test_order_emptyInput_returnsEmpty() {
        let strategy = CardCreationDateAscendingOrdering()

        let result = strategy.order([])

        XCTAssertEqual(result, [])
    }

    func test_order_singleElementInput_returnsSingleElement() {
        let strategy = CardCreationDateAscendingOrdering()
        let only = card(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )

        let result = strategy.order([only])

        XCTAssertEqual(result, [only])
    }

    func test_order_sortsByCreatedAtAscending_oldestFirst() {
        let strategy = CardCreationDateAscendingOrdering()
        // Fixed ids so the test is order-by-createdAt only; tiebreaker
        // behavior is covered by `test_order_idTiebreaker_…`.
        // Timestamps: 2024-01-01, 2024-01-15, 2024-02-01.
        let c1 = card(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            createdAt: Date(timeIntervalSince1970: 1_704_067_200)
        )
        let c2 = card(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            createdAt: Date(timeIntervalSince1970: 1_705_276_800)
        )
        let c3 = card(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            createdAt: Date(timeIntervalSince1970: 1_706_745_600)
        )

        // Pass in shuffled order to confirm the sort actually runs
        let result = strategy.order([c2, c3, c1])

        XCTAssertEqual(result.map(\.id), [c1.id, c2.id, c3.id])
    }

    func test_order_preservesOrderWhenAlreadySorted() {
        let strategy = CardCreationDateAscendingOrdering()
        let c1 = card(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let c2 = card(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            createdAt: Date(timeIntervalSince1970: 2_000)
        )
        let c3 = card(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            createdAt: Date(timeIntervalSince1970: 3_000)
        )

        let result = strategy.order([c1, c2, c3])

        XCTAssertEqual(result.map(\.id), [c1.id, c2.id, c3.id])
    }

    func test_order_idTiebreaker_forEqualCreatedAt_ascendingUUIDString() {
        let strategy = CardCreationDateAscendingOrdering()
        let sharedDate = Date(timeIntervalSince1970: 1_000)
        // "...0001".uuidString < "...0002".uuidString lexicographically
        let idOne = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let idTwo = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let cardOne = card(id: idOne, createdAt: sharedDate)
        let cardTwo = card(id: idTwo, createdAt: sharedDate)

        // Pass in reverse order to confirm the tiebreaker actually sorts them
        let result = strategy.order([cardTwo, cardOne])

        XCTAssertEqual(result.map(\.id), [idOne, idTwo])
    }

    func test_order_combinedSortAndTiebreaker() {
        let strategy = CardCreationDateAscendingOrdering()
        let t0 = Date(timeIntervalSince1970: 1_000)
        let t1 = Date(timeIntervalSince1970: 2_000)
        let t2 = Date(timeIntervalSince1970: 3_000)
        let t3 = Date(timeIntervalSince1970: 4_000)
        // a and b share t1; a.id lexicographically before b.id
        let aId = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
        let bId = UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!
        let cId = UUID(uuidString: "00000000-0000-0000-0000-0000000000CC")!
        let dId = UUID(uuidString: "00000000-0000-0000-0000-0000000000DD")!
        let eId = UUID(uuidString: "00000000-0000-0000-0000-0000000000EE")!
        let a = card(id: aId, createdAt: t1)
        let b = card(id: bId, createdAt: t1)
        let c = card(id: cId, createdAt: t0)
        let d = card(id: dId, createdAt: t2)
        let e = card(id: eId, createdAt: t3)

        let result = strategy.order([b, e, a, d, c])

        XCTAssertEqual(result.map(\.id), [cId, aId, bId, dId, eId])
    }

    func test_protocolConformance() {
        let strategy: CardOrderingStrategy = CardCreationDateAscendingOrdering()

        XCTAssertEqual(strategy.order([]).count, 0)
    }
}
