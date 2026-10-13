//
//  SettingsView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Placeholder for reminder timing and app preferences.
//

import SwiftUI

/// Root of the Settings tab.
struct SettingsView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabNavigationStack(title: AppTab.settings.title, path: $router.settingsPath) {
            PlaceholderScreen(
                title: "Preferences",
                message: "Reminder timing and app options will be managed here.",
                systemImage: AppTab.settings.systemImage,
                symbolColor: Theme.Colors.deepBlue,
                accessibilityIdentifier: "screen.settings"
            )
        }
    }
}
