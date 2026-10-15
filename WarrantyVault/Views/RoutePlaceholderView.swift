//
//  RoutePlaceholderView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Stand-in for receipt and warranty detail screens.
//

import SwiftUI

/// Temporary detail screen pushed for a typed `Route`.
struct RoutePlaceholderView: View {
    let route: Route

    var body: some View {
        PlaceholderScreen(
            title: route.title,
            message: String(localized: "Details for this screen will appear here."),
            systemImage: route.systemImage,
            symbolColor: Theme.Colors.deepBlue,
            accessibilityIdentifier: route.accessibilityIdentifier
        )
    }
}
