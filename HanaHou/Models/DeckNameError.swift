//
//  DeckNameError.swift
//  HanaHou
//
//  Feature: deck-management
//

import Foundation

enum DeckNameError: Error, Equatable {
    case empty
    case reserved(name: String)
    case duplicate(name: String)
}
