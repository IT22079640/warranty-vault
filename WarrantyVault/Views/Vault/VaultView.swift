//
//  VaultView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Placeholder for the list of saved receipts and warranty cards.
//

import SwiftUI

/// Root of the Vault tab.
struct VaultView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabNavigationStack(title: AppTab.vault.title, path: $router.vaultPath) {
            PlaceholderScreen(
                title: "Nothing saved yet",
                message: "Receipts and warranty cards you import will be listed here.",
                systemImage: AppTab.vault.systemImage,
                symbolColor: Theme.Colors.deepBlue,
                accessibilityIdentifier: "screen.vault"
            )
        }
    }
}
