//
//  AppRouterTests.swift
//  WarrantyVaultTests
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Checks that each tab keeps its own navigation path.
//

import Testing
import SwiftUI
@testable import WarrantyVault

@MainActor
struct AppRouterTests {

    /// Pushing a route selects that tab and leaves the other stacks empty.
    @Test func pushAppendsOnlyOnTheChosenTab() {
        let router = AppRouter()
        let receiptID = UUID()

        router.push(.receipt(id: receiptID), on: .insights)

        #expect(router.selectedTab == .insights)
        #expect(router.insightsPath.count == 1)
        #expect(router.vaultPath.isEmpty)
        #expect(router.addPath.isEmpty)
        #expect(router.settingsPath.isEmpty)
    }

    /// Clearing one tab does not remove destinations pushed on another tab.
    @Test func popToRootClearsOnlyThatTab() {
        let router = AppRouter()
        let identifier = UUID()

        router.push(.warranty(id: identifier), on: .settings)
        router.push(.receipt(id: identifier), on: .vault)
        router.popToRoot(for: .settings)

        #expect(router.settingsPath.isEmpty)
        #expect(router.vaultPath.count == 1)
        #expect(router.selectedTab == .vault)
    }

    /// Pop removes one screen and does nothing when that tab is already at its root.
    @Test func popRemovesOnlyTheTopScreen() {
        let router = AppRouter()
        let identifier = UUID()

        router.push(.warranty(id: identifier), on: .vault)
        router.push(.editWarranty(id: identifier), on: .vault)
        router.pop(for: .vault)

        #expect(router.vaultPath.count == 1)
        router.pop(for: .vault)
        #expect(router.vaultPath.isEmpty)
        router.pop(for: .vault)
        #expect(router.vaultPath.isEmpty)
    }
}
