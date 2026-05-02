//
//  DeckOrderingStrategy.swift
//  HanaHou
//
//  Feature: deck-management
//

import Foundation

protocol DeckOrderingStrategy {
    func order(_ decks: [DeckSnapshot]) -> [DeckSnapshot]
}

struct CreationDateAscendingOrdering: DeckOrderingStrategy {
    init() {}

    func order(_ decks: [DeckSnapshot]) -> [DeckSnapshot] {
        decks.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    }
}
