//
//  Theme.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Brand colors, Dynamic Type text styles, and layout spacing.
//

import SwiftUI

/// Shared visual tokens for Warranty Vault.
///
/// Colors come from the asset catalog so light and dark mode stay in sync.
/// Text uses system styles so Dynamic Type can scale them.
enum Theme {

    /// Brand colors. Each asset includes a dark-mode variant.
    enum Colors {
        /// Primary brand color: deep blue on light backgrounds, a lighter blue in dark mode.
        static let deepBlue = Color("DeepBlue")

        /// Secondary brand color: amber, lifted slightly in dark mode so it stays readable.
        static let amber = Color("Amber")
    }

    /// System text styles. Point sizes are intentionally not set here.
    enum Fonts {
        static let largeTitle = Font.largeTitle
        static let title = Font.title
        static let title2 = Font.title2
        static let title3 = Font.title3
        static let headline = Font.headline
        static let body = Font.body
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
        static let caption2 = Font.caption2
    }

    /// Layout spacing in points. These constants are insets and gaps, not font sizes.
    enum Spacing {
        static let extraSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }
}
