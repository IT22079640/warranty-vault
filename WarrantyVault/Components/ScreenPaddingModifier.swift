//
//  ScreenPaddingModifier.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Shared screen inset so views do not hard-code padding.
//

import SwiftUI

/// Applies the standard screen margin from the theme.
struct ScreenPaddingModifier: ViewModifier {

    /// Insets the content by the shared medium spacing.
    func body(content: Content) -> some View {
        content.padding(Theme.Spacing.medium)
    }
}

extension View {

    /// Applies the shared screen margin from `Theme.Spacing`.
    func screenPadding() -> some View {
        modifier(ScreenPaddingModifier())
    }
}
