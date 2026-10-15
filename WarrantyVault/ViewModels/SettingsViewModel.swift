//
//  SettingsViewModel.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  Permission and the reminder toggle for the Settings tab.
//

import Foundation
import Observation

/// Tracks notification permission and turns reminders on or off for every saved warranty.
@MainActor
@Observable
final class SettingsViewModel {
    private(set) var remindersEnabled = false
    private(set) var authorization: ReminderAuthorization = .notDetermined
    private(set) var statusMessage: String?
    private(set) var isUpdating = false

    /// Sentence shown when the system will not deliver reminders.
    static let deniedMessage = String(localized: "Notifications are turned off for Warranty Vault. Enable them in Settings to get reminders.")

    /// Matches the toggle to the saved preference and the current system permission.
    func refresh(
        preferences: ReminderPreferences,
        scheduler: any WarrantyReminderScheduling
    ) async {
        authorization = await scheduler.authorizationStatus()
        if authorization == .denied {
            if preferences.isEnabled {
                preferences.isEnabled = false
                await scheduler.cancelAll()
            }
            remindersEnabled = false
            statusMessage = Self.deniedMessage
            return
        }
        remindersEnabled = preferences.isEnabled && authorization == .authorized
        statusMessage = nil
    }

    /// Turns reminders on for every unarchived warranty, or removes them all.
    func setEnabled(
        _ enabled: Bool,
        repository: WarrantyRepository?,
        preferences: ReminderPreferences,
        scheduler: any WarrantyReminderScheduling,
        now: Date = .now,
        calendar: Calendar = .current
    ) async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        if !enabled {
            preferences.isEnabled = false
            remindersEnabled = false
            statusMessage = nil
            await scheduler.cancelAll()
            return
        }

        guard let repository else {
            preferences.isEnabled = false
            remindersEnabled = false
            statusMessage = String(localized: "Warranty Vault could not open saved receipts.")
            return
        }

        let permission = await scheduler.requestAuthorization()
        authorization = permission
        guard permission == .authorized else {
            preferences.isEnabled = false
            remindersEnabled = false
            statusMessage = Self.deniedMessage
            return
        }

        do {
            let items = try repository.items(
                matching: WarrantyQuery(archiveScope: .unarchived, referenceDate: now)
            )
            preferences.isEnabled = true
            remindersEnabled = true
            statusMessage = nil
            await scheduler.cancelAll()
            await scheduler.schedule(WarrantyReminderPlan.reminders(for: items, now: now, calendar: calendar))
        } catch {
            preferences.isEnabled = false
            remindersEnabled = false
            statusMessage = String(localized: "Reminders could not be scheduled.")
            await scheduler.cancelAll()
        }
    }

    /// CSV text for every warranty, or nil when there is nothing to export or the store cannot be read.
    func exportCSV(
        using repository: WarrantyRepository?,
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> String? {
        guard let repository,
              let items = try? repository.items(
                matching: WarrantyQuery(archiveScope: .all, referenceDate: date)
              ),
              !items.isEmpty else {
            return nil
        }
        return WarrantyCSV.make(items: items, on: date, calendar: calendar)
    }

    /// Schedules one notification a few seconds from now, through the same scheduler as real reminders.
    func sendTestReminder(
        scheduler: any WarrantyReminderScheduling,
        now: Date = .now
    ) async {
        var permission = await scheduler.authorizationStatus()
        if permission != .authorized {
            permission = await scheduler.requestAuthorization()
        }
        authorization = permission
        guard permission == .authorized else {
            statusMessage = Self.deniedMessage
            return
        }
        let reminder = PlannedReminder(
            identifier: WarrantyReminderPlan.testIdentifier,
            title: String(localized: "Warranty Vault"),
            body: String(localized: "This is a test reminder."),
            fireDate: now.addingTimeInterval(5)
        )
        await scheduler.schedule([reminder])
        statusMessage = String(localized: "A test reminder will appear in 5 seconds.")
    }

    /// Pending reminders, with the product name taken from the vault when the identifier matches a warranty.
    func scheduledReminders(
        using repository: WarrantyRepository?,
        scheduler: any WarrantyReminderScheduling
    ) async -> [ScheduledReminderRow] {
        let pending = await scheduler.pendingRequests()
        return pending.map { request in
            let leadDays = WarrantyReminderPlan.leadDays(in: request.identifier)
            let itemName = name(for: request, repository: repository)
            return ScheduledReminderRow(
                id: request.identifier,
                itemName: itemName,
                fireDate: request.fireDate,
                leadDays: leadDays
            )
        }
        .sorted { lhs, rhs in
            switch (lhs.fireDate, rhs.fireDate) {
            case let (left?, right?):
                return left < right
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            case (nil, nil):
                return lhs.itemName.localizedStandardCompare(rhs.itemName) == .orderedAscending
            }
        }
    }

    /// Product name for a pending request. A test notification keeps its own label.
    private func name(for request: PendingReminderRequest, repository: WarrantyRepository?) -> String {
        if request.identifier == WarrantyReminderPlan.testIdentifier {
            return String(localized: "Test reminder")
        }
        if let repository,
           let itemID = WarrantyReminderPlan.itemID(in: request.identifier),
           let item = try? repository.item(id: itemID) {
            return item.name
        }
        return request.body
    }

    /// Deletes every warranty and cancels reminders. Returns false when the store could not be cleared.
    func clearAll(
        using repository: WarrantyRepository?,
        scheduler: any WarrantyReminderScheduling,
        preferences: ReminderPreferences
    ) async -> Bool {
        guard let repository else {
            statusMessage = String(localized: "Warranty Vault could not open saved receipts.")
            return false
        }
        do {
            try repository.deleteAll()
            preferences.isEnabled = false
            remindersEnabled = false
            await scheduler.cancelAll()
            statusMessage = String(localized: "All warranties were removed.")
            return true
        } catch {
            statusMessage = String(localized: "Saved warranties could not be cleared.")
            return false
        }
    }
}
