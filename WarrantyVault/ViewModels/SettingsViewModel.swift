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
    static let deniedMessage = "Notifications are turned off for Warranty Vault. Enable them in Settings to get reminders."

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
            statusMessage = "Warranty Vault could not open saved receipts."
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
            statusMessage = "Reminders could not be scheduled."
            await scheduler.cancelAll()
        }
    }
}
