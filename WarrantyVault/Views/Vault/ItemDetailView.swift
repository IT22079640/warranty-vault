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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var item: WarrantyItem?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let item {
                detail(for: item)
            } else if loadFailed {
                PlaceholderScreen(
                    title: String(localized: "Warranty unavailable"),
                    message: String(localized: "This warranty is no longer in the vault."),
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
    @ViewBuilder
    private func header(for item: WarrantyItem) -> some View {
        let status = item.status
        let days = WarrantySummary.daysRemaining(for: item)
        if dynamicTypeSize.isAccessibilitySize {
            stackedHeader(for: item, status: status, days: days)
        } else {
            ViewThatFits(in: .horizontal) {
                wideHeader(for: item, status: status, days: days)
                    .frame(minWidth: 320, alignment: .leading)
                stackedHeader(for: item, status: status, days: days)
            }
        }
    }

    /// Ring beside the title when the row is wide enough.
    private func wideHeader(for item: WarrantyItem, status: WarrantyStatus, days: Int) -> some View {
        HStack(alignment: .center, spacing: Theme.Spacing.medium) {
            expiryRing(for: item, status: status, days: days)
            headerText(for: item, status: status, days: days)
        }
    }

    /// Ring above the title when large text needs the full width.
    private func stackedHeader(for item: WarrantyItem, status: WarrantyStatus, days: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            expiryRing(for: item, status: status, days: days)
            headerText(for: item, status: status, days: days)
        }
    }

    /// Days-remaining ring for the detail header.
    private func expiryRing(for item: WarrantyItem, status: WarrantyStatus, days: Int) -> some View {
        ExpiryRing(
            daysRemaining: days,
            progress: WarrantySummary.coverProgress(for: item),
            status: status
        )
    }

    /// Name, status, and day count beside or under the ring.
    private func headerText(for item: WarrantyItem, status: WarrantyStatus, days: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
            Text(item.name)
                .font(Theme.Fonts.title2)
                .foregroundStyle(Theme.Colors.deepBlue)
                .fixedSize(horizontal: false, vertical: true)
            Text(status.title)
                .font(Theme.Fonts.headline)
                .foregroundStyle(status.color)
                .fixedSize(horizontal: false, vertical: true)
            Text(WarrantySummary.daysLabel(days))
                .font(Theme.Fonts.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
                .accessibilityIdentifier("detail.receiptMissing")
        }
    }

    /// Stored fields that are not already in the header.
    private func facts(for item: WarrantyItem) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            fact(String(localized: "Store"), value: item.store.isEmpty ? String(localized: "Not recorded") : item.store)
            fact(String(localized: "Category"), value: item.category.title)
            fact(String(localized: "Purchased"), value: item.purchaseDate.formatted(date: .abbreviated, time: .omitted))
            fact(String(localized: "Amount"), value: AddItemRules.amountText(from: Decimal(item.amount)))
            fact(String(localized: "Warranty"), value: LocalizedFormat.string("%lld months", Int64(item.warrantyMonths)))
            fact(String(localized: "Expires"), value: item.expiryDate.formatted(date: .abbreviated, time: .omitted))
            if !item.notes.isEmpty {
                fact(String(localized: "Notes"), value: item.notes)
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
