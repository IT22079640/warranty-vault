//
//  ScheduledRemindersView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  Lists notifications still waiting in the system notification center.
//

import SwiftUI

/// One pending reminder shown in Settings.
struct ScheduledReminderRow: Identifiable, Equatable {
    /// Notification identifier.
    var id: String
    /// Product name, or the test-reminder label.
    var itemName: String
    /// When the banner is due.
    var fireDate: Date?
    /// 30, 7, or 1 when this is a planned warranty reminder. Nil for a test.
    var leadDays: Int?

    /// Second line under the product name.
    var detail: String {
        let when = fireDate?.formatted(date: .abbreviated, time: .shortened) ?? String(localized: "Waiting")
        guard let leadDays else {
            return when
        }
        return "\(leadLabel(leadDays)) · \(when)"
    }

    /// VoiceOver label for the row.
    var spoken: String {
        "\(itemName), \(detail)"
    }

    /// Words for a 30, 7, or 1 day reminder.
    private func leadLabel(_ days: Int) -> String {
        switch days {
        case 30:
            String(localized: "30 days before")
        case 7:
            String(localized: "7 days before")
        case 1:
            String(localized: "1 day before")
        default:
            LocalizedFormat.string("%lld days before", Int64(days))
        }
    }
}

/// Settings screen that reads `UNUserNotificationCenter.pendingNotificationRequests`.
struct ScheduledRemindersView: View {
    @Environment(\.warrantyRepository) private var repository
    @Environment(\.warrantyReminderScheduler) private var scheduler
    @State private var rows: [ScheduledReminderRow] = []

    var body: some View {
        Group {
            if rows.isEmpty {
                Text("No reminders are scheduled.")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("settings.pendingEmpty")
            } else {
                List(rows) { row in
                    VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                        Text(row.itemName)
                            .font(Theme.Fonts.body)
                        Text(row.detail)
                            .font(Theme.Fonts.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(row.spoken)
                    .accessibilityIdentifier("settings.pendingReminder")
                }
            }
        }
        .navigationTitle("Scheduled reminders")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("screen.scheduledReminders")
        .task {
            rows = await SettingsViewModel().scheduledReminders(using: repository, scheduler: scheduler)
        }
    }
}
