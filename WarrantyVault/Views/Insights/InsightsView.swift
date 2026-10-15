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
                if model.summary.isEmpty {
                    PlaceholderScreen(
                        title: "No insights yet",
                        message: "Save a warranty and charts for category, spending, and upcoming expiries will appear here.",
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
            .alert("Insights", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {
                    model.loadError = nil
                }
                .accessibilityIdentifier("insights.error.ok")
            } message: {
                Text(model.loadError ?? "")
            }
        }
    }

    /// True while a load failure should be shown.
    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { model.loadError != nil },
            set: { isPresented in
                if !isPresented {
                    model.loadError = nil
                }
            }
        )
    }
}
