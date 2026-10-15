//
//  PlaceholderScreen.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Empty-state layout used until a feature screen is built.
//

import SwiftUI

/// Centered icon, title, and message. An optional button retries a failed load.
struct PlaceholderScreen: View {
    let title: String
    let message: String
    let systemImage: String
    let symbolColor: Color
    let accessibilityIdentifier: String
    var actionTitle: String?
    var actionIdentifier: String?
    var action: (() -> Void)?

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: Theme.Spacing.medium) {
                    Image(systemName: systemImage)
                        .font(Theme.Fonts.largeTitle)
                        .foregroundStyle(symbolColor)
                        .accessibilityHidden(true)

                    Text(title)
                        .font(Theme.Fonts.title2)
                        .foregroundStyle(Theme.Colors.deepBlue)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(message)
                        .font(Theme.Fonts.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    if let actionTitle, let action {
                        Button(actionTitle, action: action)
                            .buttonStyle(VaultButtonStyle())
                            .accessibilityLabel(actionTitle)
                            .accessibilityHint(String(localized: "Loads this screen again"))
                            .accessibilityIdentifier(actionIdentifier ?? "\(accessibilityIdentifier).action")
                    }
                }
                .screenPadding()
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
        .accessibilityElement(children: action == nil ? .combine : .contain)
        .accessibilityLabel(action == nil ? "\(title). \(message)" : "")
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
