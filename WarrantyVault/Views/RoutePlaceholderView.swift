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
            message: "Details for this \(route.title.lowercased()) will appear here.",
            systemImage: route.systemImage,
            symbolColor: Theme.Colors.deepBlue,
            accessibilityIdentifier: route.accessibilityIdentifier
        )
    }
}
