//
//  InsightsSummaryTests.swift
//  WarrantyVaultTests
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  Checks category counts, monthly spending, protected value, and upcoming expiries.
//

import Foundation
import Testing
@testable import WarrantyVault

struct InsightsSummaryTests {
    private let calendar = WarrantyReminderFixtures.calendar

    /// Active and expiring warranties are protected. Expired ones stay in spending only.
    @Test func summarySplitsCoverFromSpending() {
        let today = WarrantyReminderFixtures.date(year: 2026, month: 10, day: 15)
        let active = WarrantyItem(
            name: "Phone",
            store: "Apple",
            purchaseDate: WarrantyReminderFixtures.date(year: 2026, month: 10, day: 1),
            amount: 100,
            warrantyMonths: 24,
            category: .phone
        )
        let expiring = WarrantyItem(
            name: "Laptop",
            store: "iShop",
            purchaseDate: today,
            amount: 25,
            warrantyMonths: 0,
            category: .laptop
        )
        let expired = WarrantyItem(
            name: "Washer",
            store: "Singer",
            purchaseDate: WarrantyReminderFixtures.date(year: 2026, month: 9, day: 1),
            amount: 50,
            warrantyMonths: 0,
            category: .appliance
        )

        let summary = InsightsSummary.make(
            items: [active, expiring, expired],
            on: today,
            calendar: calendar
        )

        #expect(summary.itemCount == 3)
        #expect(summary.isEmpty == false)
        #expect(summary.protectedValue == 125)
        #expect(summary.expiringSoonCount == 1)
        #expect(summary.categoryCounts.map(\.category) == [.phone, .laptop, .appliance])
        #expect(summary.categoryCounts.map(\.count) == [1, 1, 1])
        #expect(summary.monthlySpend.map(\.total) == [50, 125])
        #expect(summary.upcoming.map(\.name) == ["Laptop", "Phone"])
    }

    /// An empty input produces the empty state.
    @Test func emptyItemsStayEmpty() {
        let summary = InsightsSummary.make(items: [], calendar: calendar)
        #expect(summary.isEmpty)
        #expect(summary.protectedValue == 0)
        #expect(summary.upcoming.isEmpty)
    }
}

@MainActor
struct InsightsViewModelTests {

    /// Archived warranties are left out of the charts.
    @Test func reloadSkipsArchivedItems() throws {
        let repository = try WarrantyRepository(container: ModelContainerFactory.makePreviewContainer())
        let today = WarrantyReminderFixtures.date(year: 2026, month: 10, day: 15)
        _ = try repository.create(
            name: "Phone",
            store: "Apple",
            purchaseDate: today,
            amount: 100,
            warrantyMonths: 24,
            category: .phone,
            createdAt: today
        )
        _ = try repository.create(
            name: "Old sofa",
            store: "Damro",
            purchaseDate: today,
            amount: 80,
            warrantyMonths: 12,
            category: .furniture,
            isArchived: true,
            createdAt: today
        )
        let model = InsightsViewModel()
        model.reload(using: repository, on: today, calendar: WarrantyReminderFixtures.calendar)

        #expect(model.summary.itemCount == 1)
        #expect(model.summary.protectedValue == 100)
        #expect(model.summary.categoryCounts.map(\.category) == [.phone])
        #expect(model.loadError == nil)
    }
}
