//
//  InsightsSummary.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  Category counts, monthly spending, and upcoming expiries for the Insights tab.
//

import Foundation

/// Numbers and series drawn on the Insights tab.
struct InsightsSummary: Equatable {
    /// How many warranties share a category.
    struct CategoryCount: Equatable, Identifiable {
        /// Product group being counted.
        var category: ItemCategory
        /// Warranties in this group.
        var count: Int

        /// Stable chart identifier.
        var id: String { category.id }
    }

    /// Money spent on purchases that fall in one calendar month.
    struct MonthlySpend: Equatable, Identifiable {
        /// First moment of the month these purchases belong to.
        var monthStart: Date
        /// Sum of purchase amounts in that month.
        var total: Double

        /// Stable chart identifier.
        var id: TimeInterval { monthStart.timeIntervalSinceReferenceDate }
    }

    /// A warranty that has not expired yet.
    struct UpcomingExpiry: Equatable, Identifiable {
        /// Warranty identifier.
        var id: UUID
        /// Product name.
        var name: String
        /// Day cover ends.
        var expiry: Date
        /// Whole days until expiry. Zero means it ends today.
        var daysRemaining: Int
        /// Active or expiring soon. Expired rows are left out.
        var status: WarrantyStatus
    }

    /// Warranties grouped by category.
    var categoryCounts: [CategoryCount]
    /// Purchase totals for each month that has a purchase, including empty months in between.
    var monthlySpend: [MonthlySpend]
    /// Warranties that still have cover, soonest first.
    var upcoming: [UpcomingExpiry]
    /// Sum of purchase amounts for warranties that have not expired.
    var protectedValue: Double
    /// Warranties inside the 30-day window.
    var expiringSoonCount: Int
    /// Unarchived warranties included in this summary.
    var itemCount: Int

    /// True when the vault has no active, unarchived warranties to chart.
    var isEmpty: Bool { itemCount == 0 }

    /// A summary with nothing to draw.
    static let empty = InsightsSummary(
        categoryCounts: [],
        monthlySpend: [],
        upcoming: [],
        protectedValue: 0,
        expiringSoonCount: 0,
        itemCount: 0
    )

    /// Builds charts from unarchived warranties. `items` should already exclude archived rows.
    static func make(
        items: [WarrantyItem],
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> InsightsSummary {
        var counts: [ItemCategory: Int] = [:]
        var upcoming: [UpcomingExpiry] = []
        var protected = 0.0
        var expiringSoon = 0
        for item in items {
            counts[item.category, default: 0] += 1
            let status = item.status(on: date, calendar: calendar)
            if status == .expiringSoon {
                expiringSoon += 1
            }
            guard status != .expired else { continue }
            protected += item.amount
            upcoming.append(
                UpcomingExpiry(
                    id: item.id,
                    name: item.name,
                    expiry: item.expiryDate(using: calendar),
                    daysRemaining: WarrantySummary.daysRemaining(for: item, on: date, calendar: calendar),
                    status: status
                )
            )
        }
        let categoryCounts = ItemCategory.allCases.compactMap { category -> CategoryCount? in
            guard let count = counts[category], count > 0 else { return nil }
            return CategoryCount(category: category, count: count)
        }
        upcoming.sort { lhs, rhs in
            if lhs.expiry == rhs.expiry {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return lhs.expiry < rhs.expiry
        }
        return InsightsSummary(
            categoryCounts: categoryCounts,
            monthlySpend: monthlyTotals(items: items, calendar: calendar),
            upcoming: upcoming,
            protectedValue: protected,
            expiringSoonCount: expiringSoon,
            itemCount: items.count
        )
    }

    /// Sums purchase amounts by month and fills any empty month between the first and last purchase.
    private static func monthlyTotals(items: [WarrantyItem], calendar: Calendar) -> [MonthlySpend] {
        var totals: [Date: Double] = [:]
        for item in items {
            let month = startOfMonth(for: item.purchaseDate, calendar: calendar)
            totals[month, default: 0] += item.amount
        }
        guard let first = totals.keys.min(), let last = totals.keys.max() else {
            return []
        }
        var months: [MonthlySpend] = []
        var cursor = first
        while cursor <= last {
            months.append(MonthlySpend(monthStart: cursor, total: totals[cursor] ?? 0))
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor), next > cursor else {
                break
            }
            cursor = next
        }
        return months
    }

    /// Midnight at the start of the month that contains `date`.
    private static func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: parts) ?? calendar.startOfDay(for: date)
    }
}
