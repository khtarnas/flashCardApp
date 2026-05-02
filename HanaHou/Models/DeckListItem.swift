//
//  DeckListItem.swift
//  HanaHou
//
//  Feature: deck-management
//

import Foundation

enum DeckListItem: Identifiable, Equatable {
    case allCards
    case deck(DeckSnapshot)

    enum ID: Hashable {
        case allCards
        case deck(UUID)
    }

    var id: ID {
        switch self {
        case .allCards:
            return .allCards
        case .deck(let snapshot):
            return .deck(snapshot.id)
        }
    }
}
