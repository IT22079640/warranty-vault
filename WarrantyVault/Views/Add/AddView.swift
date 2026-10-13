//
//  AddView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Placeholder for importing a receipt from Photos or Files.
//

import SwiftUI

/// Root of the Add tab.
struct AddView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabNavigationStack(title: AppTab.add.title, path: $router.addPath) {
            PlaceholderScreen(
                title: "Import a receipt",
                message: "Choose a photo or a file. Warranty Vault reads it on this device.",
                systemImage: AppTab.add.systemImage,
                symbolColor: Theme.Colors.amber,
                accessibilityIdentifier: "screen.add"
            )
        }
    }
}
