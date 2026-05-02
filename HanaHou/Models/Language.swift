//
//  Language.swift
//  HanaHou
//
//  Feature: deck-management
//

import Foundation

enum Language: String, CaseIterable, Codable, Hashable {
    case english
    case japanese
    case spanish
    case mandarin
    case hawaiian
    case other
}

extension Language {
    var displayName: String {
        switch self {
        case .english: return "English"
        case .japanese: return "Japanese"
        case .spanish: return "Spanish"
        case .mandarin: return "Mandarin"
        case .hawaiian: return "Hawaiian"
        case .other: return "Other"
        }
    }
}
