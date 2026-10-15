//
//  WarrantyReminderScheduling.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  Reminder dates and the scheduler boundary used by save, archive, and Settings.
//

import Foundation
import SwiftUI

/// Whether the system will deliver warranty reminders.
enum ReminderAuthorization: Equatable, Sendable {
    /// The user has not answered the permission prompt.
    case notDetermined
    /// The user or the system will not deliver notifications.
    case denied
    /// Reminders can be scheduled.
    case authorized
}

/// One local notification ready to hand to the system.
struct PlannedReminder: Equatable, Sendable {
    /// Stable id so the same reminder can be replaced or removed.
    var identifier: String
    /// Short title shown on the notification.
    var title: String
    /// Sentence naming the product and how soon cover ends.
    var body: String
    /// Local date and time the notification should appear.
    var fireDate: Date
}

/// Stores whether the user wants warranty reminders.
struct ReminderPreferences: @unchecked Sendable {
    /// UserDefaults key for the Settings toggle.
    static let enabledKey = "warrantyRemindersEnabled"

    private let defaults: UserDefaults

    /// Reads and writes the toggle in `defaults`.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// True when the user has asked for reminders and permission was granted.
    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.enabledKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.enabledKey) }
    }
}

/// Sends and cancels warranty reminders. Tests supply a stand-in.
protocol WarrantyReminderScheduling: Sendable {
    /// Current permission, without prompting.
    func authorizationStatus() async -> ReminderAuthorization

    /// Asks for alert permission when the system still allows a prompt.
    func requestAuthorization() async -> ReminderAuthorization

    /// Adds or replaces each reminder. Identifiers already pending are updated.
    func schedule(_ reminders: [PlannedReminder]) async

    /// Removes pending and delivered reminders with these identifiers.
    func cancel(identifiers: [String]) async

    /// Removes every reminder this app has scheduled or delivered.
    func cancelAll() async
}

/// Builds the 30-day, 7-day, and 1-day reminders for a warranty.
enum WarrantyReminderPlan {
    /// How many days before expiry each reminder fires.
    static let leadDays = [30, 7, 1]

    /// Hour of the day, in the warranty calendar, when a reminder fires.
    static let fireHour = 9

    /// Identifiers for every lead day, including reminders that are no longer in the future.
    static func identifiers(for itemID: UUID) -> [String] {
        leadDays.map { identifier(itemID: itemID, daysBefore: $0) }
    }

    /// Future reminders for `item`. Lead days that would fire at or before `now` are left out.
    static func reminders(
        for item: WarrantyItem,
        now: Date,
        calendar: Calendar
    ) -> [PlannedReminder] {
        let expiry = calendar.startOfDay(for: item.expiryDate(using: calendar))
        return leadDays.compactMap { daysBefore in
            guard let reminderDay = calendar.date(byAdding: .day, value: -daysBefore, to: expiry) else {
                return nil
            }
            var parts = calendar.dateComponents([.year, .month, .day], from: reminderDay)
            parts.hour = fireHour
            parts.minute = 0
            guard let fireDate = calendar.date(from: parts), fireDate > now else {
                return nil
            }
            return PlannedReminder(
                identifier: identifier(itemID: item.id, daysBefore: daysBefore),
                title: String(localized: "Warranty Vault"),
                body: message(name: item.name, daysBefore: daysBefore),
                fireDate: fireDate
            )
        }
    }

    /// Future reminders for every item, in item order.
    static func reminders(
        for items: [WarrantyItem],
        now: Date,
        calendar: Calendar
    ) -> [PlannedReminder] {
        items.flatMap { reminders(for: $0, now: now, calendar: calendar) }
    }

    /// Stable identifier for one item and one lead day.
    static func identifier(itemID: UUID, daysBefore: Int) -> String {
        "warranty.\(itemID.uuidString).d\(daysBefore)"
    }

    /// Notification sentence for a product and a lead day.
    private static func message(name: String, daysBefore: Int) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let product = trimmed.isEmpty ? String(localized: "A saved warranty") : trimmed
        if daysBefore == 1 {
            return LocalizedFormat.string("%@ expires tomorrow.", product)
        }
        return LocalizedFormat.string("%@ expires in %lld days.", product, Int64(daysBefore))
    }
}

/// Scheduler that records nothing. Used when a screen has no scheduler injected.
struct DisabledReminderScheduler: WarrantyReminderScheduling {
    /// Reports that permission has not been requested.
    func authorizationStatus() async -> ReminderAuthorization {
        .notDetermined
    }

    /// Does not prompt, and reports that reminders cannot be sent.
    func requestAuthorization() async -> ReminderAuthorization {
        .denied
    }

    /// Ignores the reminders.
    func schedule(_ reminders: [PlannedReminder]) async {}

    /// Ignores the identifiers.
    func cancel(identifiers: [String]) async {}

    /// Ignores the request.
    func cancelAll() async {}
}

/// Environment entry for the reminder scheduler.
private struct WarrantyReminderSchedulerKey: EnvironmentKey {
    static let defaultValue: any WarrantyReminderScheduling = DisabledReminderScheduler()
}

/// Environment entry for the reminder toggle.
private struct ReminderPreferencesKey: EnvironmentKey {
    static let defaultValue = ReminderPreferences()
}

extension EnvironmentValues {
    /// Scheduler used to add and remove warranty reminders.
    var warrantyReminderScheduler: any WarrantyReminderScheduling {
        get { self[WarrantyReminderSchedulerKey.self] }
        set { self[WarrantyReminderSchedulerKey.self] = newValue }
    }

    /// The user's reminder preference.
    var reminderPreferences: ReminderPreferences {
        get { self[ReminderPreferencesKey.self] }
        set { self[ReminderPreferencesKey.self] = newValue }
    }
}
