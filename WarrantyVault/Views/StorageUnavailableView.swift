//
//  StorageUnavailableView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Shown when SwiftData cannot open a store.
//

import SwiftUI

/// Explains that saved receipts could not be opened.
struct StorageUnavailableView: View {
    var body: some View {
        PlaceholderScreen(
            title: "Storage unavailable",
            message: "Warranty Vault could not open saved receipts. Quit the app and open it again.",
            systemImage: "externaldrive.badge.exclamationmark",
            symbolColor: Theme.Colors.amber,
            accessibilityIdentifier: "screen.storageUnavailable"
        )
    }
}
