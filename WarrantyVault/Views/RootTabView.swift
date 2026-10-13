//
//  RootTabView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Top-level tabs: Vault, Add, Insights, and Settings.
//

import SwiftUI

/// The app shell. Each tab keeps its own navigation stack.
struct RootTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            configuredTab(.vault) { VaultView() }
            configuredTab(.add) { AddView() }
            configuredTab(.insights) { InsightsView() }
            configuredTab(.settings) { SettingsView() }
        }
        .tint(Theme.Colors.deepBlue)
    }

    /// Applies the shared tab label, hint, identifier, and selection tag.
    private func configuredTab<Content: View>(
        _ tab: AppTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .tabItem {
                Label(tab.title, systemImage: tab.systemImage)
            }
            .tag(tab)
            .accessibilityLabel(tab.title)
            .accessibilityHint(tab.accessibilityHint)
            .accessibilityIdentifier(tab.accessibilityIdentifier)
    }
}

#Preview {
    RootTabView()
        .environment(AppRouter())
}
