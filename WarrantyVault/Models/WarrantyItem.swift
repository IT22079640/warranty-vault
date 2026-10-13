//
//  WarrantyItem.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  One purchased product and the warranty that covers it.
//

import Foundation
import SwiftData

/// A product kept in the vault, including its receipt and warranty length.
@Model
final class WarrantyItem {
    /// Persistent identifier used by navigation and lookups.
    @Attribute(.unique) var id: UUID

    /// Product name entered by the user.
    var name: String

    /// Shop or seller the product was bought from.
    var store: String

    /// Day the product was purchased.
    var purchaseDate: Date

    /// Price paid, in the currency the user typed.
    var amount: Decimal

    /// Length of cover counted in calendar months from `purchaseDate`.
    var warrantyMonths: Int

    /// Product group used for filtering and icons.
    var category: ItemCategory

    /// Optional extra detail. Empty when the user left notes blank.
    var notes: String

    /// Receipt photo bytes. Stored outside the main database file.
    @Attribute(.externalStorage) var receiptImageData: Data?

    /// True when the user has moved the item out of the active vault.
    var isArchived: Bool

    /// Moment the record was first saved.
    var createdAt: Date

    /// Creates a warranty record. Expiry is calculated from the purchase date and month count.
    init(
        id: UUID = UUID(),
        name: String,
        store: String,
        purchaseDate: Date,
        amount: Decimal,
        warrantyMonths: Int,
        category: ItemCategory,
        notes: String = "",
        receiptImageData: Data? = nil,
        isArchived: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.store = store
        self.purchaseDate = purchaseDate
        self.amount = amount
        self.warrantyMonths = warrantyMonths
        self.category = category
        self.notes = notes
        self.receiptImageData = receiptImageData
        self.isArchived = isArchived
        self.createdAt = createdAt
    }

    /// Last day of cover, found by adding `warrantyMonths` to `purchaseDate`.
    var expiryDate: Date {
        expiryDate(using: .current)
    }

    /// Cover state for today.
    var status: WarrantyStatus {
        status(on: .now)
    }

    /// Last day of cover using `calendar` so tests can pin the result.
    func expiryDate(using calendar: Calendar) -> Date {
        calendar.date(byAdding: .month, value: warrantyMonths, to: purchaseDate) ?? purchaseDate
    }

    /// Cover state of this item on `referenceDate`.
    ///
    /// A warranty that ends today, or within the next 30 days, is expiring soon.
    /// A warranty whose expiry day is before `referenceDate` is expired.
    func status(on referenceDate: Date, calendar: Calendar = .current) -> WarrantyStatus {
        let today = calendar.startOfDay(for: referenceDate)
        let expiry = calendar.startOfDay(for: expiryDate(using: calendar))
        if expiry < today {
            return .expired
        }
        guard let threshold = calendar.date(
            byAdding: .day,
            value: WarrantyStatus.expiringSoonDayCount,
            to: today
        ) else {
            return statusFromInterval(expiry: expiry, today: today)
        }
        if expiry <= calendar.startOfDay(for: threshold) {
            return .expiringSoon
        }
        return .active
    }

    /// Covers the rare case where the calendar cannot add 30 days.
    private func statusFromInterval(expiry: Date, today: Date) -> WarrantyStatus {
        let seconds = expiry.timeIntervalSince(today)
        if seconds < 0 {
            return .expired
        }
        let soonWindow = TimeInterval(WarrantyStatus.expiringSoonDayCount * 24 * 60 * 60)
        if seconds <= soonWindow {
            return .expiringSoon
        }
        return .active
    }
}
