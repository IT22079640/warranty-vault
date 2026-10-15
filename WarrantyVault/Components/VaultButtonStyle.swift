//
//  VaultButtonStyle.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Shared filled button using the amber and deep blue theme.
//

import SwiftUI

/// Full-width button with deep blue text on an amber fill.
struct VaultButtonStyle: ButtonStyle {

    /// Draws the label with theme colors and a pressed state.
    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration)
    }
}

/// Button body that can read whether the control is enabled.
private struct StyledLabel: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(Theme.Fonts.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.small)
            .padding(.horizontal, Theme.Spacing.medium)
            .foregroundStyle(Theme.Colors.deepBlue)
            .background(
                Theme.Colors.amber.opacity(fillOpacity),
                in: RoundedRectangle(cornerRadius: 12)
            )
    }

    /// Dims the fill while pressed or disabled.
    private var fillOpacity: Double {
        if !isEnabled {
            return 0.15
        }
        return configuration.isPressed ? 0.4 : 0.28
    }
}
