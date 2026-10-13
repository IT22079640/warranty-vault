//
//  InsightsView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Placeholder for expiry reminders and warranty summaries.
//

import SwiftUI

/// Root of the Insights tab.
struct InsightsView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabNavigationStack(title: AppTab.insights.title, path: $router.insightsPath) {
            PlaceholderScreen(
                title: "No insights yet",
                message: "Expiry reminders and warranty summaries will appear here.",
                systemImage: AppTab.insights.systemImage,
                symbolColor: Theme.Colors.deepBlue,
                accessibilityIdentifier: "screen.insights"
            )
        }
    }
}
