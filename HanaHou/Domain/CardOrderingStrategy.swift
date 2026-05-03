//
//  CardOrderingStrategy.swift
//  HanaHou
//
//  Feature: card-management
//

import Foundation

/// Strategy for ordering a list of `CardSnapshot` values. Kept as a
/// Card-side sibling of `DeckOrderingStrategy` (not a generic
/// `OrderingStrategy<Item>`) per the approved card-management design —
/// symmetry with the existing deck-side pattern is more valuable than
/// marginal DRY at P0 scale.
protocol CardOrderingStrategy {
    func order(_ cards: [CardSnapshot]) -> [CardSnapshot]
}

/// Default ordering: ascending by `createdAt` (oldest first), with the
/// card's `id.uuidString` as a deterministic tiebreaker when two cards
/// share the same `createdAt` value (Req 2 AC 3, 5 AC 4).
struct CardCreationDateAscendingOrdering: CardOrderingStrategy {
    init() {}

    func order(_ cards: [CardSnapshot]) -> [CardSnapshot] {
        cards.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    }
}
