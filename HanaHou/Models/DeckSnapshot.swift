//
//  DeckSnapshot.swift
//  HanaHou
//
//  Feature: deck-management
//

import Foundation

struct DeckSnapshot: Equatable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let frontLanguage: Language
    let backLanguage: Language
    let createdAt: Date
    let updatedAt: Date
}
