//
//  EditWarrantyView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Loads one saved warranty into the shared form.
//

import SwiftUI

/// Edit screen that reuses the add form with its own view model.
struct EditWarrantyView: View {
    let itemID: UUID

    @Environment(\.warrantyRepository) private var repository
    @State private var model = AddItemViewModel(minimumReadDuration: .zero)
    @State private var loadFailed = false

    var body: some View {
        Group {
            if loadFailed {
                PlaceholderScreen(
                    title: String(localized: "Warranty unavailable"),
                    message: String(localized: "This warranty is no longer in the vault."),
                    systemImage: "questionmark.folder",
                    symbolColor: Theme.Colors.amber,
                    accessibilityIdentifier: "screen.editWarranty.missing"
                )
            } else if model.isEditing {
                AddItemFormView()
            } else {
                ProgressView("Loading warranty…")
                    .font(Theme.Fonts.body)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .environment(model)
        .task {
            load()
        }
        .accessibilityIdentifier("screen.editWarranty")
    }

    /// Copies the saved warranty into the form.
    private func load() {
        guard !model.isEditing else {
            return
        }
        guard let repository, let item = try? repository.item(id: itemID) else {
            loadFailed = true
            return
        }
        model.loadExisting(item)
    }
}
