//
//  VaultWarrantyCard.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  One warranty summary that stacks on a narrow width and sits in a row when wide.
//

import SwiftUI

/// Summary of a saved warranty, used in the list and the adaptive grid.
struct VaultWarrantyCard: View {
    let item: WarrantyItem
    var referenceDate: Date = .now

    var body: some View {
        ViewThatFits(in: .horizontal) {
            wideLayout
                .frame(minWidth: 280, alignment: .leading)
            compactLayout
        }
        .cardStyle()
        .vaultMatchedTransition(id: item.id, isSource: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenSummary)
        .accessibilityIdentifier("vault.card.\(item.id.uuidString)")
    }

    /// Side-by-side layout for a list row or a wide grid cell.
    private var wideLayout: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.medium) {
            thumbnail
            details
        }
    }

    /// Stacked layout for a narrow phone column.
    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            HStack(alignment: .center, spacing: Theme.Spacing.small) {
                thumbnail
                Text(item.name)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.deepBlue)
                    .lineLimit(2)
            }
            statusLine
            Text(metaLine)
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    /// Product name, shop, and cover state.
    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
            Text(item.name)
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.deepBlue)
                .lineLimit(2)
            Text(item.store.isEmpty ? item.category.title : item.store)
                .font(Theme.Fonts.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            statusLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Status title and days remaining in the status color.
    private var statusLine: some View {
        Label(WarrantySummary.daysLabel(days), systemImage: status.symbolName)
            .font(Theme.Fonts.caption)
            .foregroundStyle(status.color)
            .lineLimit(1)
    }

    /// Receipt thumbnail, or the category symbol when no photo is stored.
    private var thumbnail: some View {
        Group {
            if let data = item.receiptImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: item.category.symbolName)
                    .font(Theme.Fonts.title2)
                    .foregroundStyle(item.category.color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(item.category.color.opacity(0.12))
            }
        }
        .frame(width: Theme.Spacing.extraLarge * 2, height: Theme.Spacing.extraLarge * 2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }

    /// Shop and price on one line for the stacked card.
    private var metaLine: String {
        let amount = AddItemRules.amountText(from: Decimal(item.amount))
        if item.store.isEmpty {
            return amount
        }
        return "\(item.store) · \(amount)"
    }

    /// Cover state used for color and the spoken label.
    private var status: WarrantyStatus {
        item.status(on: referenceDate)
    }

    /// Days from today until expiry.
    private var days: Int {
        WarrantySummary.daysRemaining(for: item, on: referenceDate)
    }

    /// Combined label for VoiceOver.
    private var spokenSummary: String {
        let place = item.store.isEmpty ? item.category.title : item.store
        return "\(item.name), \(place), \(status.title), \(WarrantySummary.daysLabel(days))"
    }
}
