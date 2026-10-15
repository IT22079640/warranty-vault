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
        HStack(alignment: .top, spacing: Theme.Spacing.medium) {
            metric(
                title: "Total value protected",
                value: AddItemRules.amountText(from: Decimal(summary.protectedValue)),
                identifier: "insights.protectedValue"
            )
            metric(
                title: "Expiring soon",
                value: "\(summary.expiringSoonCount)",
                identifier: "insights.expiringSoonCount"
            )
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(summaryLabel)
        .accessibilityIdentifier("insights.summary")
    }

    /// How many saved warranties sit in each category.
    private var categoryChart: some View {
        chartSection(title: "Items by category", identifier: "insights.categories") {
            Chart(summary.categoryCounts) { entry in
                BarMark(
                    x: .value("Category", entry.category.title),
                    y: .value("Items", entry.count)
                )
                .foregroundStyle(entry.category.color)
                .accessibilityLabel("\(entry.category.title), \(entry.count) items")
            }
            .frame(height: chartHeight)
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                        .font(Theme.Fonts.caption)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(Theme.Fonts.caption)
                }
            }
        }
        .accessibilityLabel(categoryLabel)
    }

    /// Purchase totals grouped by month.
    private var spendingChart: some View {
        chartSection(title: "Spending by month", identifier: "insights.spending") {
            Chart(summary.monthlySpend) { entry in
                BarMark(
                    x: .value("Month", entry.monthStart, unit: .month),
                    y: .value("Spent", entry.total)
                )
                .foregroundStyle(Theme.Colors.deepBlue)
                .accessibilityLabel(spendLabel(for: entry))
            }
            .frame(height: chartHeight)
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                        .font(Theme.Fonts.caption)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).year())
                        .font(Theme.Fonts.caption)
                }
            }
        }
        .accessibilityLabel(spendingLabel)
    }

    /// Each warranty that still has cover, placed on its expiry date.
    private var timelineChart: some View {
        chartSection(title: "Upcoming expiries", identifier: "insights.timeline") {
            if summary.upcoming.isEmpty {
                Text("No warranties are still in date.")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("insights.timeline.empty")
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
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(Theme.Fonts.caption)
                    }
                }
            }
        }
        .accessibilityLabel(timelineLabel)
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
        let amount = AddItemRules.amountText(from: Decimal(summary.protectedValue))
        return "Total value protected \(amount). Expiring soon \(summary.expiringSoonCount)."
    }

    /// Spoken category counts.
    private var categoryLabel: String {
        let parts = summary.categoryCounts.map { "\($0.category.title), \($0.count)" }
        return "Items by category. \(parts.joined(separator: ". "))."
    }

    /// Spoken monthly totals.
    private var spendingLabel: String {
        let parts = summary.monthlySpend.map { spendLabel(for: $0) }
        return "Spending by month. \(parts.joined(separator: ". "))."
    }

    /// Spoken upcoming expiries.
    private var timelineLabel: String {
        if summary.upcoming.isEmpty {
            return "Upcoming expiries. No warranties are still in date."
        }
        let parts = summary.upcoming.map { "\($0.name), \(WarrantySummary.daysLabel($0.daysRemaining))" }
        return "Upcoming expiries. \(parts.joined(separator: ". "))."
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
                .minimumScaleFactor(0.6)
                .lineLimit(1)
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
        let amount = AddItemRules.amountText(from: Decimal(entry.total))
        return "\(month), \(amount)"
    }
}
