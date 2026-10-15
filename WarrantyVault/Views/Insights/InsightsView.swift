//
//  InsightsView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Charts and a summary of the warranties still in the vault.
//

import SwiftUI

/// Root of the Insights tab.
struct InsightsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.warrantyRepository) private var repository
    @State private var model = InsightsViewModel()

    var body: some View {
        @Bindable var router = router
        TabNavigationStack(title: AppTab.insights.title, path: $router.insightsPath) {
            Group {
                if model.isLoading && model.summary.isEmpty && model.loadError == nil {
                    LoadingScreen(
                        message: String(localized: "Loading insights…"),
                        accessibilityIdentifier: "screen.insights.loading"
                    )
                } else if let loadError = model.loadError {
                    PlaceholderScreen(
                        title: String(localized: "Insights unavailable"),
                        message: loadError,
                        systemImage: "exclamationmark.triangle",
                        symbolColor: Theme.Colors.amberInk,
                        accessibilityIdentifier: "screen.insights.error",
                        actionTitle: String(localized: "Try again"),
                        actionIdentifier: "insights.retry",
                        action: { model.reload(using: repository) }
                    )
                } else if model.summary.isEmpty {
                    PlaceholderScreen(
                        title: String(localized: "No insights yet"),
                        message: String(localized: "Save a warranty and charts for category, spending, and upcoming expiries will appear here."),
                        systemImage: AppTab.insights.systemImage,
                        symbolColor: Theme.Colors.deepBlue,
                        accessibilityIdentifier: "screen.insights.empty"
                    )
                } else {
                    InsightsCharts(summary: model.summary)
                }
            }
            .onAppear {
                model.reload(using: repository)
            }
            .onChange(of: router.selectedTab) { _, tab in
                if tab == .insights {
                    model.reload(using: repository)
                }
            }
        }
    }
}
