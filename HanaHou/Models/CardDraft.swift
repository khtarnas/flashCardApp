//
//  CardDraft.swift
//  HanaHou
//
//  Feature: card-management
//

import Foundation

/// User-editable, pre-persistence value type for a Card. Crosses the
/// persistence boundary so the domain and view-model layers never touch
/// `NSManagedObject`. Deck membership is supplied separately at create
/// time (see `CardStore.create`); it is intentionally not part of the
/// draft.
struct CardDraft: Equatable {
    var frontText: String
    var backText: String
}
