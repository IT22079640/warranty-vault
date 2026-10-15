//
//  ItemDetailView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  One warranty, its receipt, days remaining, edit, and share.
//

import SwiftUI

/// Detail screen pushed from a vault card.
struct ItemDetailView: View {
    let itemID: UUID

    @Environment(AppRouter.self) private var router
    @Environment(\.warrantyRepository) private var repository
    @State private var item: WarrantyItem?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let item {
                detail(for: item)
            } else if loadFailed {
                PlaceholderScreen(
                    title: "Warranty unavailable",
                    message: "This warranty is no longer in the vault.",
                    systemImage: "questionmark.folder",
                    symbolColor: Theme.Colors.amber,
                    accessibilityIdentifier: "screen.warranty.missing"
                )
            } else {
                ProgressView("Loading warranty…")
                    .font(Theme.Fonts.body)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: itemID) {
            load()
        }
        .onAppear(perform: load)
    }

    /// Receipt, ring, and facts for a loaded warranty.
    private func detail(for item: WarrantyItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                header(for: item)
                    .vaultMatchedTransition(id: item.id, isSource: false)
                receipt(for: item)
                facts(for: item)
            }
            .padding(Theme.Spacing.medium)
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: WarrantySummary.shareText(for: item)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .accessibilityLabel("Share warranty summary")
                .accessibilityHint("Opens the share sheet with a text summary")
                .accessibilityIdentifier("detail.share")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.push(.editWarranty(id: item.id), on: .vault)
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }
                .accessibilityLabel("Edit warranty")
                .accessibilityHint("Opens the form to change this warranty")
                .accessibilityIdentifier("detail.edit")
            }
        }
        .accessibilityIdentifier("screen.warranty")
    }

    /// Ring and title that continue the vault card animation.
    private func header(for item: WarrantyItem) -> some View {
        let status = item.status
        let days = WarrantySummary.daysRemaining(for: item)
        return HStack(alignment: .center, spacing: Theme.Spacing.medium) {
            ExpiryRing(
                daysRemaining: days,
                progress: WarrantySummary.coverProgress(for: item),
                status: status
            )
            VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                Text(item.name)
                    .font(Theme.Fonts.title2)
                    .foregroundStyle(Theme.Colors.deepBlue)
                Text(status.title)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(status.color)
                Text(WarrantySummary.daysLabel(days))
                    .font(Theme.Fonts.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Zoomable receipt, or a short note when no photo was saved.
    @ViewBuilder
    private func receipt(for item: WarrantyItem) -> some View {
        if let data = item.receiptImageData, let image = UIImage(data: data) {
            ZoomableReceiptImage(image: image)
                .cardStyle()
        } else {
            Text("No receipt photo")
                .font(Theme.Fonts.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
                .accessibilityIdentifier("detail.receiptMissing")
        }
    }

    /// Stored fields that are not already in the header.
    private func facts(for item: WarrantyItem) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            fact("Store", value: item.store.isEmpty ? "Not recorded" : item.store)
            fact("Category", value: item.category.title)
            fact("Purchased", value: item.purchaseDate.formatted(date: .abbreviated, time: .omitted))
            fact("Amount", value: AddItemRules.amountText(from: Decimal(item.amount)))
            fact("Warranty", value: "\(item.warrantyMonths) months")
            fact("Expires", value: item.expiryDate.formatted(date: .abbreviated, time: .omitted))
            if !item.notes.isEmpty {
                fact("Notes", value: item.notes)
            }
        }
        .cardStyle()
        .accessibilityIdentifier("detail.facts")
    }

    /// One labeled line inside the facts card.
    private func fact(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
            Text(title)
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Theme.Fonts.body)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Reads the warranty again so an edit shows up after the form closes.
    private func load() {
        guard let repository else {
            loadFailed = true
            return
        }
        do {
            item = try repository.item(id: itemID)
            loadFailed = item == nil
        } catch {
            item = nil
            loadFailed = true
        }
    }
}
