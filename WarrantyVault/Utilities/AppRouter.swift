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
    /// Scanning screen shown while a chosen receipt is read.
    case addReview
    /// Editable warranty form, with or without a scanned receipt.
    case addForm
    /// Form for changing a warranty that is already saved.
    case editWarranty(id: UUID)

    /// Short title shown in the navigation bar.
    var title: String {
        switch self {
        case .receipt:
            String(localized: "Receipt")
        case .warranty:
            String(localized: "Warranty")
        case .addReview:
            String(localized: "Reading receipt")
        case .addForm:
            String(localized: "Warranty details")
        case .editWarranty:
            String(localized: "Edit warranty")
        }
    }

    /// SF Symbol that represents this destination.
    var systemImage: String {
        switch self {
        case .receipt:
            "doc.text"
        case .warranty:
            "checkmark.seal"
        case .addReview:
            "doc.viewfinder"
        case .addForm:
            "square.and.pencil"
        case .editWarranty:
            "square.and.pencil"
        }
    }

    /// Stable identifier for UI tests.
    var accessibilityIdentifier: String {
        switch self {
        case .receipt:
            "screen.receipt"
        case .warranty:
            "screen.warranty"
        case .addReview:
            "screen.addReview"
        case .addForm:
            "screen.addForm"
        case .editWarranty:
            "screen.editWarranty"
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
            String(localized: "Vault")
        case .add:
            String(localized: "Add")
        case .insights:
            String(localized: "Insights")
        case .settings:
            String(localized: "Settings")
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
            String(localized: "Shows saved receipts and warranty cards")
        case .add:
            String(localized: "Imports a receipt from Photos or Files")
        case .insights:
            String(localized: "Shows warranty expiry summaries")
        case .settings:
            String(localized: "Opens reminder and app preferences")
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

    /// Replaces the stack for `tab` with `routes`, in order.
    func replacePath(with routes: [Route], on tab: AppTab) {
        var path = NavigationPath()
        for route in routes {
            path.append(route)
        }
        selectedTab = tab
        switch tab {
        case .vault:
            vaultPath = path
        case .add:
            addPath = path
        case .insights:
            insightsPath = path
        case .settings:
            settingsPath = path
        }
    }

    /// Removes the top screen on `tab` when the stack is not empty.
    func pop(for tab: AppTab) {
        switch tab {
        case .vault:
            guard !vaultPath.isEmpty else { return }
            vaultPath.removeLast()
        case .add:
            guard !addPath.isEmpty else { return }
            addPath.removeLast()
        case .insights:
            guard !insightsPath.isEmpty else { return }
            insightsPath.removeLast()
        case .settings:
            guard !settingsPath.isEmpty else { return }
            settingsPath.removeLast()
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
