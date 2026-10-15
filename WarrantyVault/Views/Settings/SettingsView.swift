//
//  SettingsView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Reminders, appearance, export, and about.
//

import SwiftUI
import UIKit

/// Root of the Settings tab.
struct SettingsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.warrantyRepository) private var repository
    @Environment(\.warrantyReminderScheduler) private var scheduler
    @Environment(\.reminderPreferences) private var preferences
    @Environment(\.openURL) private var openURL
    @AppStorage(AppearanceChoice.storageKey) private var appearanceRaw = AppearanceChoice.system.rawValue
    @State private var model = SettingsViewModel()
    @State private var confirmClear = false

    var body: some View {
        @Bindable var router = router
        TabNavigationStack(title: AppTab.settings.title, path: $router.settingsPath) {
            Form {
                reminderSection
                appearanceSection
                exportSection
                dataSection
                aboutSection
            }
            .accessibilityIdentifier("screen.settings")
            .confirmationDialog(
                String(localized: "Clear all warranties?"),
                isPresented: $confirmClear,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Clear all data"), role: .destructive) {
                    Task {
                        _ = await model.clearAll(
                            using: repository,
                            scheduler: scheduler,
                            preferences: preferences
                        )
                    }
                }
                .accessibilityLabel(String(localized: "Clear all data"))
                .accessibilityIdentifier("settings.confirmClear")
                Button(String(localized: "Cancel"), role: .cancel) {}
                    .accessibilityLabel(String(localized: "Cancel"))
                    .accessibilityIdentifier("settings.cancelClear")
            } message: {
                Text("This removes every receipt and warranty from this device. This cannot be undone.")
            }
            .task {
                await model.refresh(preferences: preferences, scheduler: scheduler)
            }
            .onChange(of: router.selectedTab) { _, tab in
                guard tab == .settings else { return }
                Task {
                    await model.refresh(preferences: preferences, scheduler: scheduler)
                }
            }
        }
    }

    /// Reminder toggle, permission status, and the system Settings link.
    private var reminderSection: some View {
        Section {
            Toggle(isOn: reminderBinding) {
                Text("Warranty reminders")
                    .font(Theme.Fonts.body)
            }
            .disabled(model.isUpdating)
            .accessibilityLabel(String(localized: "Warranty reminders"))
            .accessibilityHint(String(localized: "Schedules a reminder 30 days, 7 days, and 1 day before each warranty ends"))
            .accessibilityIdentifier("settings.reminders")

            if let statusMessage = model.statusMessage {
                Text(statusMessage)
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(Theme.Colors.amberInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.reminderStatus")
            }

            if model.authorization == .denied {
                Button(String(localized: "Open Settings")) {
                    openSystemSettings()
                }
                .font(Theme.Fonts.body)
                .accessibilityLabel(String(localized: "Open Settings"))
                .accessibilityHint(String(localized: "Opens iOS Settings for Warranty Vault"))
                .accessibilityIdentifier("settings.openSystemSettings")
            }

            Button(String(localized: "Send test reminder")) {
                Task {
                    await model.sendTestReminder(scheduler: scheduler)
                }
            }
            .font(Theme.Fonts.body)
            .disabled(model.isUpdating)
            .accessibilityLabel(String(localized: "Send test reminder"))
            .accessibilityHint(String(localized: "Schedules a notification in 5 seconds"))
            .accessibilityIdentifier("settings.sendTestReminder")

            Button(String(localized: "Scheduled reminders")) {
                router.push(.scheduledReminders, on: .settings)
            }
            .font(Theme.Fonts.body)
            .accessibilityLabel(String(localized: "Scheduled reminders"))
            .accessibilityHint(String(localized: "Shows reminders that are waiting to be delivered"))
            .accessibilityIdentifier("settings.scheduledReminders")
        } footer: {
            Text("Reminders are sent at 9:00 in the morning, 30 days, 7 days, and 1 day before a warranty ends. Editing a warranty updates its reminders. Archiving or deleting it cancels them.")
                .font(Theme.Fonts.footnote)
        }
    }

    /// System, light, or dark appearance.
    private var appearanceSection: some View {
        Section {
            AccessibleChoicePicker(
                title: String(localized: "Appearance"),
                selection: appearanceBinding,
                options: AppearanceChoice.allCases,
                optionTitle: { $0.title },
                accessibilityIdentifier: "settings.appearance"
            )
            .accessibilityHint(String(localized: "Chooses light, dark, or the device setting"))
        } footer: {
            Text("System follows the appearance set on this device.")
                .font(Theme.Fonts.footnote)
        }
    }

    /// Shares a CSV of every saved warranty.
    private var exportSection: some View {
        Section {
            if let csv = model.exportCSV(using: repository) {
                ShareLink(
                    item: WarrantyCSVDocument(text: csv),
                    preview: SharePreview(String(localized: "Warranty Vault.csv"))
                ) {
                    Label(String(localized: "Export CSV"), systemImage: "square.and.arrow.up")
                        .font(Theme.Fonts.body)
                }
                .accessibilityLabel(String(localized: "Export CSV"))
                .accessibilityHint(String(localized: "Shares a spreadsheet of every saved warranty"))
                .accessibilityIdentifier("settings.exportCSV")
            } else {
                Text("No warranties to export")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.exportEmpty")
            }
        } header: {
            Text("Export")
        }
    }

    /// Destructive clear of the vault.
    private var dataSection: some View {
        Section {
            Button(String(localized: "Clear all data"), role: .destructive) {
                confirmClear = true
            }
            .font(Theme.Fonts.body)
            .accessibilityLabel(String(localized: "Clear all data"))
            .accessibilityHint(String(localized: "Asks before deleting every warranty"))
            .accessibilityIdentifier("settings.clearAll")
        } header: {
            Text("Data")
        } footer: {
            Text("Clearing data also cancels warranty reminders.")
                .font(Theme.Fonts.footnote)
        }
    }

    /// App name and version.
    private var aboutSection: some View {
        Section {
            LabeledContent(String(localized: "Version"), value: appVersion)
                .font(Theme.Fonts.body)
                .accessibilityIdentifier("settings.version")
            Text("Warranty Vault stores receipts and reminds you before a warranty ends. Reading a receipt happens on this device.")
                .font(Theme.Fonts.body)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("settings.aboutBody")
        } header: {
            Text("About")
        }
    }

    /// Writes the toggle through permission and scheduling.
    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { model.remindersEnabled },
            set: { enabled in
                Task {
                    await model.setEnabled(
                        enabled,
                        repository: repository,
                        preferences: preferences,
                        scheduler: scheduler
                    )
                }
            }
        )
    }

    /// Stores the appearance choice.
    private var appearanceBinding: Binding<AppearanceChoice> {
        Binding(
            get: { AppearanceChoice(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }

    /// Marketing version and build from the app bundle.
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    /// Opens the system page where notification permission can be changed.
    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        openURL(url)
    }
}
