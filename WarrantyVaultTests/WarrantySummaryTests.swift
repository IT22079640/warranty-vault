//
//  WarrantySummaryTests.swift
//  WarrantyVaultTests
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Checks days remaining, ring progress, and the share summary.
//

import Foundation
import Testing
@testable import WarrantyVault

struct WarrantySummaryTests {
    private let calendar = Calendar(identifier: .gregorian)

    /// Days count to the expiry day, and progress stays between zero and one.
    @Test func daysAndProgressStayInRange() {
        let purchase = date(year: 2026, month: 1, day: 1)
        let today = date(year: 2026, month: 10, day: 14)
        let item = WarrantyItem(
            name: "Kettle",
            store: "Abans",
            purchaseDate: purchase,
            amount: 49.5,
            warrantyMonths: 12,
            category: .appliance
        )

        let days = WarrantySummary.daysRemaining(for: item, on: today, calendar: calendar)
        let expiry = calendar.startOfDay(for: item.expiryDate(using: calendar))
        let expected = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: today),
            to: expiry
        ).day

        #expect(days == expected)
        #expect(days > 0)
        let progress = WarrantySummary.coverProgress(for: item, on: today, calendar: calendar)
        #expect(progress > 0)
        #expect(progress < 1)
    }

    /// An expired warranty reports overdue days and an empty ring.
    @Test func expiredCoverIsOverdue() {
        let item = WarrantyItem(
            name: "Washer",
            store: "Singer",
            purchaseDate: date(year: 2024, month: 1, day: 1),
            amount: 640,
            warrantyMonths: 12,
            category: .appliance
        )
        let today = date(year: 2026, month: 10, day: 14)
        let days = WarrantySummary.daysRemaining(for: item, on: today, calendar: calendar)

        #expect(days < 0)
        #expect(WarrantySummary.coverProgress(for: item, on: today, calendar: calendar) == 0)
        #expect(WarrantySummary.daysLabel(days).contains("overdue"))
    }

    /// The share text includes the product, shop, status, and day count.
    @Test func shareTextIncludesTheSummary() {
        let item = WarrantyItem(
            name: "MacBook Air",
            store: "iShop",
            purchaseDate: date(year: 2026, month: 1, day: 1),
            amount: 1899,
            warrantyMonths: 24,
            category: .laptop
        )
        let text = WarrantySummary.shareText(
            for: item,
            on: date(year: 2026, month: 10, day: 14),
            calendar: calendar
        )

        #expect(text.contains("MacBook Air"))
        #expect(text.contains("Store: iShop"))
        #expect(text.contains("Category: Laptop"))
        #expect(text.contains("Warranty: 24 months"))
        #expect(text.contains("Status: Active"))
        #expect(text.contains("days left"))
    }

    /// Makes a Gregorian date at midnight.
    private func date(year: Int, month: Int, day: Int) -> Date {
        var calendar = calendar
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day
        )
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }
}
