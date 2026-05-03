//
//  CardRowItem.swift
//  HanaHou
//
//  Feature: card-management
//

import Foundation

/// Display-only row model used by `CardListView` and `AllCardsView` to render
/// individual card rows. The list view models map `CardSnapshot` → `CardRowItem`
/// during reload so views don't have to translate snapshots into display data
/// inline.
///
/// - Note: `id` equals the underlying `CardSnapshot.id`, so a row tap can be
///   resolved back to its `CardSnapshot` via the view model's `snapshotsById`
///   map (see design §ViewModels / `CardListViewModel`).
/// - Note: `isOrphan` is derived from `snapshot.deckIds.isEmpty` — a card is
///   an Orphaned_Card when it is not associated with any deck (Req 6).
struct CardRowItem: Identifiable, Equatable, Hashable {
    let id: UUID
    let frontText: String
    let backText: String
    let isOrphan: Bool
}
