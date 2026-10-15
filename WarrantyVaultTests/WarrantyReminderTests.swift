//
//  WarrantyReminderTests.swift
//  WarrantyVaultTests
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  Checks reminder dates and that save, edit, archive, and delete talk to the scheduler.
//

import Foundation
import Testing
import UIKit
@testable import WarrantyVault

struct WarrantyReminderPlanTests {
    private let calendar = WarrantyReminderFixtures.calendar

    /// A warranty far from expiry gets a reminder 30, 7, and 1 day before, at 9:00.
    @Test func futureCoverSchedulesThreeReminders() {
        let item = WarrantyReminderFixtures.item(
            name: "Kettle",
            purchase: WarrantyReminderFixtures.date(year: 2026, month: 1, day: 1),
            months: 12
        )
        let now = WarrantyReminderFixtures.date(year: 2026, month: 6, day: 1)
        let reminders = WarrantyReminderPlan.reminders(for: item, now: now, calendar: calendar)

        #expect(reminders.count == 3)
        #expect(reminders.map(\.body) == [
            "Kettle expires in 30 days.",
            "Kettle expires in 7 days.",
            "Kettle expires tomorrow."
        ])
        let expected = [
            WarrantyReminderFixtures.date(year: 2026, month: 12, day: 2, hour: 9),
            WarrantyReminderFixtures.date(year: 2026, month: 12, day: 25, hour: 9),
            WarrantyReminderFixtures.date(year: 2026, month: 12, day: 31, hour: 9)
        ]
        #expect(reminders.map(\.fireDate) == expected)
        #expect(reminders.map(\.identifier) == WarrantyReminderPlan.identifiers(for: item.id))
    }

    /// Lead days that would already have fired are omitted, but their identifiers can still be cancelled.
    @Test func pastLeadDaysAreSkipped() {
        let item = WarrantyReminderFixtures.item(
            name: "Kettle",
            purchase: WarrantyReminderFixtures.date(year: 2026, month: 1, day: 1),
            months: 12
        )
        let now = WarrantyReminderFixtures.date(year: 2026, month: 12, day: 20)
        let reminders = WarrantyReminderPlan.reminders(for: item, now: now, calendar: calendar)

        #expect(reminders.map(\.body) == [
            "Kettle expires in 7 days.",
            "Kettle expires tomorrow."
        ])
        #expect(WarrantyReminderPlan.identifiers(for: item.id).count == 3)
    }

    /// A warranty that has already ended has no future reminder, but the old identifiers still exist to cancel.
    @Test func expiredCoverSchedulesNothing() {
        let item = WarrantyReminderFixtures.item(
            name: "Kettle",
            purchase: WarrantyReminderFixtures.date(year: 2024, month: 1, day: 1),
            months: 6
        )
        let now = WarrantyReminderFixtures.date(year: 2026, month: 6, day: 1)
        let reminders = WarrantyReminderPlan.reminders(for: item, now: now, calendar: calendar)

        #expect(reminders.isEmpty)
        #expect(WarrantyReminderPlan.identifiers(for: item.id).count == 3)
    }

    /// A blank product name still produces a readable notification.
    @Test func blankNameUsesTheFallback() {
        let item = WarrantyReminderFixtures.item(
            name: "   ",
            purchase: WarrantyReminderFixtures.date(year: 2026, month: 1, day: 1),
            months: 12
        )
        let now = WarrantyReminderFixtures.date(year: 2026, month: 6, day: 1)
        let reminders = WarrantyReminderPlan.reminders(for: item, now: now, calendar: calendar)

        #expect(reminders.first?.body == "A saved warranty expires in 30 days.")
    }
}

@MainActor
struct WarrantyReminderFlowTests {

    /// Saving with reminders on schedules them, and a later edit replaces them.
    @Test func saveAndEditReplaceReminders() async throws {
        let repository = try WarrantyRepository(container: ModelContainerFactory.makePreviewContainer())
        let preferences = try WarrantyReminderFixtures.preferences(enabled: true)
        let scheduler = MockReminderScheduler()
        let model = WarrantyReminderFixtures.formModel()
        let now = WarrantyReminderFixtures.date(year: 2026, month: 6, day: 1)
        model.productName = "Kettle"
        model.store = "Abans"
        model.amountText = "40"
        model.purchaseDate = WarrantyReminderFixtures.date(year: 2026, month: 1, day: 1)
        model.warrantyLength = .twelve

        #expect(await model.save(
            using: repository,
            reminders: scheduler,
            preferences: preferences,
            now: now,
            calendar: WarrantyReminderFixtures.calendar
        ))
        #expect(scheduler.scheduledBatches.count == 1)
        #expect(scheduler.scheduledBatches[0].count == 3)
        #expect(scheduler.cancelCalls.count == 1)

        let saved = try repository.items().first
        #expect(saved != nil)
        guard let saved else { return }
        model.loadExisting(saved)
        model.warrantyLength = .custom
        model.customMonths = "1"
        #expect(await model.save(
            using: repository,
            reminders: scheduler,
            preferences: preferences,
            now: now,
            calendar: WarrantyReminderFixtures.calendar
        ))
        #expect(scheduler.cancelCalls.count == 2)
        #expect(scheduler.scheduledBatches.last?.isEmpty == true)
        #expect(scheduler.cancelCalls.last == WarrantyReminderPlan.identifiers(for: saved.id))
    }

    /// A save while the toggle is off does not schedule or cancel.
    @Test func saveSkipsRemindersWhenDisabled() async throws {
        let repository = try WarrantyRepository(container: ModelContainerFactory.makePreviewContainer())
        let preferences = try WarrantyReminderFixtures.preferences(enabled: false)
        let scheduler = MockReminderScheduler()
        let model = WarrantyReminderFixtures.formModel()
        model.productName = "Kettle"
        model.amountText = "40"

        #expect(await model.save(
            using: repository,
            reminders: scheduler,
            preferences: preferences
        ))
        #expect(scheduler.scheduledBatches.isEmpty)
        #expect(scheduler.cancelCalls.isEmpty)
    }

    /// Saving a warranty that has already ended clears its identifiers and does not schedule a new one.
    @Test func saveOfExpiredWarrantyCancelsWithoutAFutureReminder() async throws {
        let repository = try WarrantyRepository(container: ModelContainerFactory.makePreviewContainer())
        let preferences = try WarrantyReminderFixtures.preferences(enabled: true)
        let scheduler = MockReminderScheduler()
        let model = WarrantyReminderFixtures.formModel()
        model.productName = "Old kettle"
        model.amountText = "40"
        model.purchaseDate = WarrantyReminderFixtures.date(year: 2020, month: 1, day: 1)
        model.warrantyLength = .six

        #expect(await model.save(
            using: repository,
            reminders: scheduler,
            preferences: preferences,
            now: WarrantyReminderFixtures.date(year: 2026, month: 6, day: 1),
            calendar: WarrantyReminderFixtures.calendar
        ))
        #expect(scheduler.cancelCalls.count == 1)
        #expect(scheduler.scheduledBatches == [[]])
    }

    /// Archive and delete remove that warranty's three reminder identifiers.
    @Test func archiveAndDeleteCancelReminders() async throws {
        let repository = try WarrantyRepository(container: ModelContainerFactory.makePreviewContainer())
        let created = try repository.create(
            name: "Kettle",
            store: "Abans",
            purchaseDate: .now,
            amount: 40,
            warrantyMonths: 12,
            category: .appliance
        )
        let scheduler = MockReminderScheduler()
        let model = VaultViewModel()
        let expected = WarrantyReminderPlan.identifiers(for: created.id)

        await model.archive(created, using: repository, reminders: scheduler)
        #expect(scheduler.cancelCalls == [expected])

        let second = try repository.create(
            name: "Lamp",
            store: "Softlogic",
            purchaseDate: .now,
            amount: 20,
            warrantyMonths: 6,
            category: .furniture
        )
        await model.delete(second, using: repository, reminders: scheduler)
        #expect(scheduler.cancelCalls.last == WarrantyReminderPlan.identifiers(for: second.id))
    }

    /// Turning the toggle on asks for permission and schedules every unarchived warranty.
    @Test func settingsToggleSchedulesAndCancels() async throws {
        let repository = try WarrantyRepository(container: ModelContainerFactory.makePreviewContainer())
        _ = try repository.create(
            name: "Kettle",
            store: "Abans",
            purchaseDate: WarrantyReminderFixtures.date(year: 2026, month: 1, day: 1),
            amount: 40,
            warrantyMonths: 12,
            category: .appliance
        )
        let preferences = try WarrantyReminderFixtures.preferences(enabled: false)
        let scheduler = MockReminderScheduler()
        scheduler.requestResult = .authorized
        let model = SettingsViewModel()
        let now = WarrantyReminderFixtures.date(year: 2026, month: 6, day: 1)

        await model.setEnabled(
            true,
            repository: repository,
            preferences: preferences,
            scheduler: scheduler,
            now: now,
            calendar: WarrantyReminderFixtures.calendar
        )
        #expect(model.remindersEnabled)
        #expect(preferences.isEnabled)
        #expect(scheduler.cancelAllCount == 1)
        #expect(scheduler.scheduledBatches.last?.count == 3)

        await model.setEnabled(
            false,
            repository: repository,
            preferences: preferences,
            scheduler: scheduler,
            now: now,
            calendar: WarrantyReminderFixtures.calendar
        )
        #expect(model.remindersEnabled == false)
        #expect(preferences.isEnabled == false)
        #expect(scheduler.cancelAllCount == 2)
    }

    /// A denied prompt leaves the toggle off and does not schedule.
    @Test func deniedPermissionStaysOff() async throws {
        let repository = try WarrantyRepository(container: ModelContainerFactory.makePreviewContainer())
        let preferences = try WarrantyReminderFixtures.preferences(enabled: false)
        let scheduler = MockReminderScheduler()
        scheduler.requestResult = .denied
        let model = SettingsViewModel()

        await model.setEnabled(
            true,
            repository: repository,
            preferences: preferences,
            scheduler: scheduler
        )
        #expect(model.remindersEnabled == false)
        #expect(preferences.isEnabled == false)
        #expect(model.statusMessage == SettingsViewModel.deniedMessage)
        #expect(scheduler.scheduledBatches.isEmpty)
    }

    /// If permission is later revoked, the saved toggle is cleared and reminders are removed.
    @Test func refreshClearsRemindersWhenPermissionIsDenied() async throws {
        let preferences = try WarrantyReminderFixtures.preferences(enabled: true)
        let scheduler = MockReminderScheduler()
        scheduler.authorization = .denied
        let model = SettingsViewModel()

        await model.refresh(preferences: preferences, scheduler: scheduler)
        #expect(preferences.isEnabled == false)
        #expect(model.remindersEnabled == false)
        #expect(scheduler.cancelAllCount == 1)
        #expect(model.statusMessage == SettingsViewModel.deniedMessage)
    }
}

/// Scheduler stand-in that records schedule and cancel calls.
final class MockReminderScheduler: WarrantyReminderScheduling, @unchecked Sendable {
    var authorization: ReminderAuthorization = .notDetermined
    var requestResult: ReminderAuthorization = .authorized
    private(set) var scheduledBatches: [[PlannedReminder]] = []
    private(set) var cancelCalls: [[String]] = []
    private(set) var cancelAllCount = 0

    /// Returns the canned status.
    func authorizationStatus() async -> ReminderAuthorization {
        authorization
    }

    /// Stores the canned prompt result as the current status.
    func requestAuthorization() async -> ReminderAuthorization {
        authorization = requestResult
        return requestResult
    }

    /// Records one schedule call.
    func schedule(_ reminders: [PlannedReminder]) async {
        scheduledBatches.append(reminders)
    }

    /// Records one cancel call.
    func cancel(identifiers: [String]) async {
        cancelCalls.append(identifiers)
    }

    /// Records a request to remove every reminder.
    func cancelAll() async {
        cancelAllCount += 1
    }
}

/// Shared dates and form setup for reminder tests.
enum WarrantyReminderFixtures {
    /// Gregorian calendar fixed at UTC so reminder hours do not shift.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        return calendar
    }()

    /// A form view model that does not read a receipt.
    @MainActor
    static func formModel() -> AddItemViewModel {
        AddItemViewModel(
            recognizer: ReminderReceiptRecognizer(),
            suggester: CategorySuggester(keywords: [:], embedding: nil),
            minimumReadDuration: .zero
        )
    }

    /// A warranty that is not inserted into a store.
    static func item(name: String, purchase: Date, months: Int) -> WarrantyItem {
        WarrantyItem(
            name: name,
            store: "Abans",
            purchaseDate: purchase,
            amount: 40,
            warrantyMonths: months,
            category: .appliance
        )
    }

    /// Isolated defaults so tests do not change the app's toggle.
    static func preferences(enabled: Bool) throws -> ReminderPreferences {
        let name = "warranty-reminders-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else {
            throw PreferenceSuiteError.unavailable
        }
        defaults.removePersistentDomain(forName: name)
        let preferences = ReminderPreferences(defaults: defaults)
        preferences.isEnabled = enabled
        return preferences
    }

    /// A UTC date from calendar parts.
    static func date(year: Int, month: Int, day: Int, hour: Int = 0) -> Date {
        var parts = DateComponents()
        parts.calendar = calendar
        parts.timeZone = calendar.timeZone
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        return calendar.date(from: parts) ?? Date(timeIntervalSince1970: 0)
    }
}

/// Failure when a private UserDefaults suite cannot be opened.
private enum PreferenceSuiteError: Error {
    case unavailable
}

/// Recognizer that returns no lines.
private struct ReminderReceiptRecognizer: TextRecognizing {
    /// Returns an empty receipt.
    func recognizeText(in image: UIImage) async throws -> [RecognizedLine] {
        []
    }
}
