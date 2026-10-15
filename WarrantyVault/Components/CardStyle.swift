//
//  CardStyle.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Shared card chrome for vault rows and other summary blocks.
//

import SwiftUI

/// Padding, rounded background, and a light border used by vault cards.
struct CardStyle: ViewModifier {

    /// Draws the content inside the shared card chrome.
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Theme.Colors.deepBlue.opacity(0.18), lineWidth: 1)
            }
    }
}

extension View {
    /// Applies the shared vault card background, padding, and border.
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
