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
