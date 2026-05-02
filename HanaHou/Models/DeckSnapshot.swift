//
//  DeckSnapshot.swift
//  HanaHou
//
//  Feature: deck-management
//

import Foundation

/// Immutable value type representing a Deck row as it crosses the persistence
/// boundary. View models and views consume `DeckSnapshot`, not `NSManagedObject`,
/// which is what keeps the domain layer decoupled from Core Data.
///
/// - Note: `Hashable` conformance is needed because `DeckSnapshot` is carried
///   inside `DeckManagementRoute` values that are pushed onto `NavigationPath`.
///   SwiftUI requires navigation values to be `Hashable`.
struct DeckSnapshot: Equatable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let frontLanguage: Language
    let backLanguage: Language
    let createdAt: Date
    let updatedAt: Date
}
