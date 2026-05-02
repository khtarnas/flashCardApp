//
//  DeckListComposer.swift
//  HanaHou
//
//  Feature: deck-management
//

import Foundation

enum DeckListComposer {
    static func compose(
        userDecks: [DeckSnapshot],
        strategy: DeckOrderingStrategy
    ) -> [DeckListItem] {
        [.allCards] + strategy.order(userDecks).map(DeckListItem.deck)
    }
}
