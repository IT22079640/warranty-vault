//
//  AppRouter.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Typed routes and the navigation state for each tab.
//

import SwiftUI

/// Push destinations shared by every tab's navigation stack.
enum Route: Hashable {
    /// A saved receipt, identified by its persistent id.
    case receipt(id: UUID)
    /// A saved warranty card, identified by its persistent id.
    case warranty(id: UUID)

    /// Short title shown in the navigation bar.
    var title: String {
        switch self {
        case .receipt:
            "Receipt"
        case .warranty:
            "Warranty"
        }
    }

    /// SF Symbol that represents this destination.
    var systemImage: String {
        switch self {
        case .receipt:
            "doc.text"
        case .warranty:
            "checkmark.seal"
        }
    }

    /// Stable identifier for UI tests.
    var accessibilityIdentifier: String {
        switch self {
        case .receipt:
            "screen.receipt"
        case .warranty:
            "screen.warranty"
        }
    }
}

/// The four primary sections of Warranty Vault.
enum AppTab: Hashable, CaseIterable {
    case vault
    case add
    case insights
    case settings

    /// Title shown in the tab bar.
    var title: String {
        switch self {
        case .vault:
            "Vault"
        case .add:
            "Add"
        case .insights:
            "Insights"
        case .settings:
            "Settings"
        }
    }

    /// SF Symbol shown in the tab bar.
    var systemImage: String {
        switch self {
        case .vault:
            "archivebox"
        case .add:
            "plus.circle"
        case .insights:
            "chart.bar"
        case .settings:
            "gearshape"
        }
    }

    /// Spoken hint for the tab button.
    var accessibilityHint: String {
        switch self {
        case .vault:
            "Shows saved receipts and warranty cards"
        case .add:
            "Imports a receipt from Photos or Files"
        case .insights:
            "Shows warranty expiry summaries"
        case .settings:
            "Opens reminder and app preferences"
        }
    }

    /// Stable identifier for UI tests.
    var accessibilityIdentifier: String {
        switch self {
        case .vault:
            "tab.vault"
        case .add:
            "tab.add"
        case .insights:
            "tab.insights"
        case .settings:
            "tab.settings"
        }
    }
}

/// Owns the selected tab and a navigation path for each tab.
@Observable
final class AppRouter {
    var selectedTab: AppTab = .vault
    var vaultPath = NavigationPath()
    var addPath = NavigationPath()
    var insightsPath = NavigationPath()
    var settingsPath = NavigationPath()

    /// Shows `tab` and pushes `route` onto that tab's stack.
    func push(_ route: Route, on tab: AppTab) {
        selectedTab = tab
        switch tab {
        case .vault:
            vaultPath.append(route)
        case .add:
            addPath.append(route)
        case .insights:
            insightsPath.append(route)
        case .settings:
            settingsPath.append(route)
        }
    }

    /// Clears every pushed screen on `tab`.
    func popToRoot(for tab: AppTab) {
        switch tab {
        case .vault:
            vaultPath = NavigationPath()
        case .add:
            addPath = NavigationPath()
        case .insights:
            insightsPath = NavigationPath()
        case .settings:
            settingsPath = NavigationPath()
        }
    }
}
