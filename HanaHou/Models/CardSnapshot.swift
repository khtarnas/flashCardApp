//
//  CardSnapshot.swift
//  HanaHou
//
//  Feature: card-management
//

import Foundation

/// Immutable value type representing a Card row as it crosses the persistence
/// boundary. View models and views consume `CardSnapshot`, not `NSManagedObject`,
/// which is what keeps the domain layer decoupled from Core Data.
///
/// - Note: `deckIds` is the many-to-many carrier (D003). An empty set identifies
///   an Orphaned_Card — a Card that is not associated with any Deck, surfaced
///   by the All Cards view after its last Deck is deleted (Req 6).
/// - Note: `Hashable` conformance is needed because `CardSnapshot` is carried
///   inside `DeckManagementRoute` values that are pushed onto `NavigationPath`.
///   SwiftUI requires navigation values to be `Hashable`.
struct CardSnapshot: Equatable, Identifiable, Hashable {
    let id: UUID
    let frontText: String
    let backText: String
    let createdAt: Date
    let updatedAt: Date
    let deckIds: Set<UUID>
}
