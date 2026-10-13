//
//  WarrantyVaultTests.swift
//  WarrantyVaultTests
//
//  Created by Ama Hitiarachchi  on 2026-10-12.
//
//  Checks expiry dates, cover status, and category presentation.
//

import Foundation
import Testing
@testable import WarrantyVault

struct WarrantyVaultTests {

    private let calendar = Calendar(identifier: .gregorian)

    /// Twelve months from 13 October 2026 lands on 13 October 2027.
    @Test func expiryDateAddsWarrantyMonths() {
        let purchase = date(year: 2026, month: 10, day: 13)
        let item = makeItem(purchaseDate: purchase, warrantyMonths: 12)

        let expiry = item.expiryDate(using: calendar)

        #expect(calendar.component(.year, from: expiry) == 2027)
        #expect(calendar.component(.month, from: expiry) == 10)
        #expect(calendar.component(.day, from: expiry) == 13)
    }

    /// A warranty that ended yesterday is expired.
    @Test func statusIsExpiredBeforeToday() {
        let today = date(year: 2026, month: 6, day: 15)
        let item = makeItem(purchaseDate: date(year: 2025, month: 6, day: 14), warrantyMonths: 12)

        #expect(item.status(on: today, calendar: calendar) == .expired)
    }

    /// A warranty that ends today is still inside the 30-day window.
    @Test func statusIsExpiringSoonOnTheExpiryDay() {
        let today = date(year: 2026, month: 6, day: 15)
        let item = makeItem(purchaseDate: date(year: 2025, month: 6, day: 15), warrantyMonths: 12)

        #expect(item.status(on: today, calendar: calendar) == .expiringSoon)
    }

    /// Day 30 is still expiring soon. Day 31 is active.
    @Test func statusChangesAfterThirtyDays() {
        let today = date(year: 2026, month: 1, day: 1)
        let onDay30 = makeItem(purchaseDate: date(year: 2025, month: 1, day: 31), warrantyMonths: 12)
        let onDay31 = makeItem(purchaseDate: date(year: 2025, month: 2, day: 1), warrantyMonths: 12)

        #expect(onDay30.expiryDate(using: calendar) == date(year: 2026, month: 1, day: 31))
        #expect(onDay30.status(on: today, calendar: calendar) == .expiringSoon)
        #expect(onDay31.status(on: today, calendar: calendar) == .active)
    }

    /// Every category has a title, an SF Symbol, and a distinct raw value.
    @Test func categoriesExposeSymbolAndTitle() {
        #expect(ItemCategory.allCases.map(\.rawValue) == [
            "phone", "laptop", "appliance", "furniture", "vehicle", "other"
        ])
        #expect(ItemCategory.phone.symbolName == "iphone")
        #expect(ItemCategory.laptop.symbolName == "laptopcomputer")
        #expect(ItemCategory.appliance.symbolName == "washer")
        #expect(ItemCategory.furniture.symbolName == "sofa")
        #expect(ItemCategory.vehicle.symbolName == "car")
        #expect(ItemCategory.other.symbolName == "shippingbox")
        #expect(ItemCategory.allCases.allSatisfy { !$0.title.isEmpty && !$0.symbolName.isEmpty })
    }

    /// Builds a warranty without saving it.
    private func makeItem(purchaseDate: Date, warrantyMonths: Int) -> WarrantyItem {
        WarrantyItem(
            name: "Test product",
            store: "Test store",
            purchaseDate: purchaseDate,
            amount: 10,
            warrantyMonths: warrantyMonths,
            category: .other
        )
    }

    /// Makes a Gregorian date at midnight.
    private func date(year: Int, month: Int, day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }
}
