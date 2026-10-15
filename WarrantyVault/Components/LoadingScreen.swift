//
//  LoadingScreen.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  Centered progress message used while a screen is loading.
//

import SwiftUI

/// Spinner and message that can scroll when Dynamic Type is very large.
struct LoadingScreen: View {
    let message: String
    let accessibilityIdentifier: String

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: Theme.Spacing.medium) {
                    ProgressView()
                        .controlSize(.large)
                        .accessibilityHidden(true)
                    Text(message)
                        .font(Theme.Fonts.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .screenPadding()
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
