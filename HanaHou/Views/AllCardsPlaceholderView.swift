//
//  AllCardsPlaceholderView.swift
//  HanaHou
//
//  Feature: deck-management
//

import SwiftUI

struct AllCardsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("All Cards")
                .font(.title2.weight(.semibold))
            Text("Coming in the card-management spec.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("All Cards")
    }
}
