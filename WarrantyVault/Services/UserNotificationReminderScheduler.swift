//
//  UserNotificationReminderScheduler.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  Local notifications for warranty reminders, plus foreground presentation.
//

import Foundation
import UserNotifications

/// Schedules warranty reminders with `UNUserNotificationCenter`.
final class UserNotificationReminderScheduler: WarrantyReminderScheduling, @unchecked Sendable {
    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    /// Uses the shared notification center and the current calendar.
    init(center: UNUserNotificationCenter = .current(), calendar: Calendar = .current) {
        self.center = center
        self.calendar = calendar
    }

    /// Reads the system authorization without showing a prompt.
    func authorizationStatus() async -> ReminderAuthorization {
        let settings = await center.notificationSettings()
        return Self.authorization(from: settings.authorizationStatus)
    }

    /// Prompts for alerts and sound when iOS still allows it.
    func requestAuthorization() async -> ReminderAuthorization {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return await authorizationStatus()
        }
        return await authorizationStatus()
    }

    /// Adds each reminder. A matching identifier replaces a pending request.
    func schedule(_ reminders: [PlannedReminder]) async {
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let parts = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminder.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            let request = UNNotificationRequest(
                identifier: reminder.identifier,
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
            } catch {
                continue
            }
        }
    }

    /// Removes pending and already delivered reminders for these identifiers.
    func cancel(identifiers: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    /// Clears every pending and delivered notification for this app.
    func cancelAll() async {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    /// Maps a system status onto the app's three permission cases.
    private static func authorization(from status: UNAuthorizationStatus) -> ReminderAuthorization {
        switch status {
        case .authorized, .provisional, .ephemeral:
            .authorized
        case .denied:
            .denied
        case .notDetermined:
            .notDetermined
        @unknown default:
            .denied
        }
    }
}

/// Shows a banner when a reminder arrives while Warranty Vault is open.
final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    /// Presents a banner, sound, and notification list entry in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
