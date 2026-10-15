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
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.small)
            .padding(.horizontal, Theme.Spacing.medium)
            .foregroundStyle(isEnabled ? Theme.Colors.buttonInk : Color.secondary)
            .background(
                Theme.Colors.buttonFill.opacity(fillOpacity),
                in: RoundedRectangle(cornerRadius: Theme.Radius.control)
            )
    }

    /// Dims the fill while pressed or disabled.
    private var fillOpacity: Double {
        if !isEnabled {
            return 0.35
        }
        return configuration.isPressed ? 0.75 : 1
    }
}
