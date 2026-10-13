//
//  PlaceholderScreen.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Empty-state layout used until a feature screen is built.
//

import SwiftUI

/// Centered icon, title, and message for a screen that is not built yet.
struct PlaceholderScreen: View {
    let title: String
    let message: String
    let systemImage: String
    let symbolColor: Color
    let accessibilityIdentifier: String

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            Image(systemName: systemImage)
                .font(Theme.Fonts.largeTitle)
                .foregroundStyle(symbolColor)
                .accessibilityHidden(true)

            Text(title)
                .font(Theme.Fonts.title2)
                .foregroundStyle(Theme.Colors.deepBlue)
                .multilineTextAlignment(.center)

            Text(message)
                .font(Theme.Fonts.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .screenPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
