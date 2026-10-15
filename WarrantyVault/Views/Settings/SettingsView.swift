//
//  SettingsView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Reminder permission and the toggle that schedules warranty notifications.
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
    @State private var model = SettingsViewModel()

    var body: some View {
        @Bindable var router = router
        TabNavigationStack(title: AppTab.settings.title, path: $router.settingsPath) {
            Form {
                Section {
                    Toggle(isOn: reminderBinding) {
                        Text("Warranty reminders")
                            .font(Theme.Fonts.body)
                    }
                    .disabled(model.isUpdating)
                    .accessibilityLabel("Warranty reminders")
                    .accessibilityHint("Schedules a reminder 30 days, 7 days, and 1 day before each warranty ends")
                    .accessibilityIdentifier("settings.reminders")

                    if let statusMessage = model.statusMessage {
                        Text(statusMessage)
                            .font(Theme.Fonts.callout)
                            .foregroundStyle(Theme.Colors.amber)
                            .accessibilityIdentifier("settings.reminderStatus")
                    }

                    if model.authorization == .denied {
                        Button("Open Settings") {
                            openSystemSettings()
                        }
                        .font(Theme.Fonts.body)
                        .accessibilityHint("Opens iOS Settings for Warranty Vault")
                        .accessibilityIdentifier("settings.openSystemSettings")
                    }
                } footer: {
                    Text("Reminders are sent at 9:00 in the morning, 30 days, 7 days, and 1 day before a warranty ends. Editing a warranty updates its reminders. Archiving or deleting it cancels them.")
                        .font(Theme.Fonts.footnote)
                }
            }
            .accessibilityIdentifier("screen.settings")
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

    /// Opens the system page where notification permission can be changed.
    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        openURL(url)
    }
}
