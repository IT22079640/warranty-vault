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
        var category: ItemCategory
        var count: Int

        /// Stable chart identifier.
        var id: String { category.id }
    }

    /// Money spent on purchases that fall in one calendar month.
    struct MonthlySpend: Equatable, Identifiable {
        var monthStart: Date
        var total: Double

        /// Stable chart identifier.
        var id: TimeInterval { monthStart.timeIntervalSinceReferenceDate }
    }

    /// A warranty that has not expired yet.
    struct UpcomingExpiry: Equatable, Identifiable {
        var id: UUID
        var name: String
        var expiry: Date
        var daysRemaining: Int
        var status: WarrantyStatus
    }

    var categoryCounts: [CategoryCount]
    var monthlySpend: [MonthlySpend]
    var upcoming: [UpcomingExpiry]
    var protectedValue: Double
    var expiringSoonCount: Int
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
        let counts = ItemCategory.allCases.compactMap { category -> CategoryCount? in
            let count = items.filter { $0.category == category }.count
            guard count > 0 else { return nil }
            return CategoryCount(category: category, count: count)
        }
        let upcoming = items.compactMap { item -> UpcomingExpiry? in
            let status = item.status(on: date, calendar: calendar)
            guard status != .expired else { return nil }
            return UpcomingExpiry(
                id: item.id,
                name: item.name,
                expiry: item.expiryDate(using: calendar),
                daysRemaining: WarrantySummary.daysRemaining(for: item, on: date, calendar: calendar),
                status: status
            )
        }
        .sorted { lhs, rhs in
            if lhs.expiry == rhs.expiry {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return lhs.expiry < rhs.expiry
        }
        let protected = items.reduce(0.0) { partial, item in
            guard item.status(on: date, calendar: calendar) != .expired else { return partial }
            return partial + item.amount
        }
        let expiringSoon = items.filter { $0.status(on: date, calendar: calendar) == .expiringSoon }.count
        return InsightsSummary(
            categoryCounts: counts,
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
