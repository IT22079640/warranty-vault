//
//  RootTabView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Top-level tabs: Vault, Add, Insights, and Settings.
//

import SwiftData
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

#Preview("Sample warranties") {
    SampleVaultPreview()
}

/// Preview host that loads the in-memory sample warranties.
@MainActor
private struct SampleVaultPreview: View {
    private let container: ModelContainer?

    /// Loads the in-memory sample store, or leaves it nil when that fails.
    init() {
        container = try? WarrantySampleData.makePreviewContainer()
    }

    var body: some View {
        if let container {
            RootTabView()
                .environment(AppRouter())
                .environment(\.warrantyRepository, WarrantyRepository(container: container))
                .modelContainer(container)
        } else {
            Text("Sample warranties could not be loaded")
                .font(Theme.Fonts.body)
        }
    }
}
