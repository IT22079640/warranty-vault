//
//  InsightsCharts.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  Swift Charts for category counts, monthly spending, and upcoming expiries.
//

import Charts
import SwiftUI

/// Category, spending, and expiry charts plus the protected-value card.
struct InsightsCharts: View {
    let summary: InsightsSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                summaryCard
                categoryChart
                spendingChart
                timelineChart
            }
            .screenPadding()
        }
        .accessibilityIdentifier("screen.insights")
    }

    /// Total value still covered, and how many warranties are close to ending.
    private var summaryCard: some View {
        ViewThatFits(in: .horizontal) {
            summaryMetrics
                .frame(minWidth: 360, alignment: .leading)
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                metric(
                    title: String(localized: "Total value protected"),
                    value: CurrencyFormatter.string(from: Decimal(summary.protectedValue)),
                    identifier: "insights.protectedValue"
                )
                metric(
                    title: String(localized: "Expiring soon"),
                    value: "\(summary.expiringSoonCount)",
                    identifier: "insights.expiringSoonCount"
                )
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(summaryLabel)
        .accessibilityIdentifier("insights.summary")
    }

    /// The two headline numbers side by side.
    private var summaryMetrics: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.medium) {
            metric(
                title: String(localized: "Total value protected"),
                value: CurrencyFormatter.string(from: Decimal(summary.protectedValue)),
                identifier: "insights.protectedValue"
            )
            metric(
                title: String(localized: "Expiring soon"),
                value: "\(summary.expiringSoonCount)",
                identifier: "insights.expiringSoonCount"
            )
        }
    }

    /// How many saved warranties sit in each category.
    private var categoryChart: some View {
        chartSection(title: String(localized: "Items by category"), identifier: "insights.categories") {
            if prefersText {
                textRows(summary.categoryCounts.map { "\($0.category.title): \($0.count)" })
            } else {
                Chart(summary.categoryCounts) { entry in
                    BarMark(
                        x: .value("Category", entry.category.title),
                        y: .value("Items", entry.count)
                    )
                    .foregroundStyle(entry.category.color)
                    .accessibilityLabel(LocalizedFormat.string("%@, %lld items", entry.category.title, Int64(entry.count)))
                }
                .frame(height: chartHeight)
                .chartYAxis { axisMarks }
                .chartXAxis { axisMarks }
            }
        }
        .accessibilityLabel(categoryLabel)
    }

    /// Purchase totals grouped by month.
    private var spendingChart: some View {
        chartSection(title: String(localized: "Spending by month"), identifier: "insights.spending") {
            if prefersText {
                textRows(summary.monthlySpend.map { spendText(for: $0) })
            } else {
                Chart(summary.monthlySpend) { entry in
                    BarMark(
                        x: .value("Month", entry.monthStart, unit: .month),
                        y: .value("Spent", entry.total)
                    )
                    .foregroundStyle(Theme.Colors.deepBlue)
                    .accessibilityLabel(spendLabel(for: entry))
                }
                .frame(height: chartHeight)
                .chartYAxis { currencyAxis }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).year())
                            .font(Theme.Fonts.caption)
                    }
                }
            }
        }
        .accessibilityLabel(spendingLabel)
    }

    /// Each warranty that still has cover, placed on its expiry date.
    private var timelineChart: some View {
        chartSection(title: String(localized: "Upcoming expiries"), identifier: "insights.timeline") {
            if summary.upcoming.isEmpty {
                Text(String(localized: "No warranties are still in date."))
                    .font(Theme.Fonts.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("insights.timeline.empty")
            } else if prefersText {
                textRows(summary.upcoming.map { "\($0.name), \(WarrantySummary.daysLabel($0.daysRemaining))" })
            } else {
                Chart(summary.upcoming) { entry in
                    PointMark(
                        x: .value("Expires", entry.expiry, unit: .day),
                        y: .value("Warranty", entry.name)
                    )
                    .foregroundStyle(entry.status.color)
                    .symbolSize(Theme.Spacing.extraLarge * 3)
                    .accessibilityLabel("\(entry.name), \(WarrantySummary.daysLabel(entry.daysRemaining))")
                }
                .frame(height: timelineHeight)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day())
                            .font(Theme.Fonts.caption)
                    }
                }
                .chartYAxis { axisMarks }
            }
        }
        .accessibilityLabel(timelineLabel)
    }

    /// True when charts should be replaced by wrapping text.
    private var prefersText: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    /// Rupee labels on the spending axis, using a scaling text style.
    private var currencyAxis: some AxisContent {
        AxisMarks { value in
            AxisGridLine()
            AxisValueLabel {
                if let amount = value.as(Double.self) {
                    Text(CurrencyFormatter.string(from: Decimal(amount)))
                        .font(Theme.Fonts.caption)
                }
            }
        }
    }

    /// Shared axis styling that uses a scaling text style.
    private var axisMarks: some AxisContent {
        AxisMarks { _ in
            AxisGridLine()
            AxisValueLabel()
                .font(Theme.Fonts.caption)
        }
    }

    /// Wrapping rows used at the largest Dynamic Type sizes.
    private func textRows(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(Theme.Fonts.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Height of the category and spending charts.
    private var chartHeight: CGFloat {
        Theme.Spacing.extraLarge * 6
    }

    /// Taller frame when each warranty needs its own row.
    private var timelineHeight: CGFloat {
        max(chartHeight, CGFloat(summary.upcoming.count) * Theme.Spacing.extraLarge + Theme.Spacing.large)
    }

    /// Spoken summary of the two headline numbers.
    private var summaryLabel: String {
        let amount = CurrencyFormatter.spoken(from: Decimal(summary.protectedValue))
        return LocalizedFormat.string(
            "Total value protected %@. Expiring soon %lld.",
            amount,
            Int64(summary.expiringSoonCount)
        )
    }

    /// Spoken category counts.
    private var categoryLabel: String {
        let parts = summary.categoryCounts.map { "\($0.category.title), \($0.count)" }
        let heading = String(localized: "Items by category")
        return "\(heading). \(parts.joined(separator: ". "))."
    }

    /// Spoken monthly totals.
    private var spendingLabel: String {
        let parts = summary.monthlySpend.map { spendLabel(for: $0) }
        let heading = String(localized: "Spending by month")
        return "\(heading). \(parts.joined(separator: ". "))."
    }

    /// Spoken upcoming expiries.
    private var timelineLabel: String {
        let heading = String(localized: "Upcoming expiries")
        if summary.upcoming.isEmpty {
            let empty = String(localized: "No warranties are still in date.")
            return "\(heading). \(empty)"
        }
        let parts = summary.upcoming.map { "\($0.name), \(WarrantySummary.daysLabel($0.daysRemaining))" }
        return "\(heading). \(parts.joined(separator: ". "))."
    }

    /// One headline figure inside the summary card.
    private func metric(title: String, value: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
            Text(title)
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Theme.Fonts.title2)
                .foregroundStyle(Theme.Colors.deepBlue)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(identifier)
    }

    /// Title plus a chart, sharing the card chrome.
    private func chartSection<Content: View>(
        title: String,
        identifier: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text(title)
                .font(Theme.Fonts.title3)
                .foregroundStyle(Theme.Colors.deepBlue)
            content()
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    /// Month and amount for one spending bar.
    private func spendLabel(for entry: InsightsSummary.MonthlySpend) -> String {
        let month = entry.monthStart.formatted(.dateTime.month(.wide).year())
        let amount = CurrencyFormatter.spoken(from: Decimal(entry.total))
        return "\(month), \(amount)"
    }

    /// Month and rupee amount shown when charts are replaced by text.
    private func spendText(for entry: InsightsSummary.MonthlySpend) -> String {
        let month = entry.monthStart.formatted(.dateTime.month(.wide).year())
        let amount = CurrencyFormatter.string(from: Decimal(entry.total))
        return "\(month), \(amount)"
    }
}
