//
//  WarrantyVaultApp.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi  on 2026-10-12.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct WarrantyVaultApp: App {
    @State private var router = AppRouter()
    @AppStorage(OnboardingStorage.finishedKey) private var hasFinishedOnboarding = false
    @AppStorage(AppearanceChoice.storageKey) private var appearanceRaw = AppearanceChoice.system.rawValue
    private let modelContainerResult: Result<ModelContainer, Error>
    private let reminderScheduler = UserNotificationReminderScheduler()
    private let notificationDelegate = ReminderNotificationDelegate()

    init() {
        modelContainerResult = Result { try ModelContainerFactory.makeContainer() }
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            root
                .preferredColorScheme(appearance.colorScheme)
        }
    }

    /// Introduction on first launch, otherwise the tab shell or a storage error.
    @ViewBuilder
    private var root: some View {
        if showsOnboarding {
            OnboardingView {
                hasFinishedOnboarding = true
            }
        } else {
            switch modelContainerResult {
            case .success(let container):
                RootTabView()
                    .environment(router)
                    .environment(
                        \.warrantyRepository,
                        WarrantyRepository(container: container)
                    )
                    .environment(\.warrantyReminderScheduler, reminderScheduler)
                    .modelContainer(container)
            case .failure:
                StorageUnavailableView()
            }
        }
    }

    /// True until the introduction is finished, unless a test asks to skip it.
    private var showsOnboarding: Bool {
        if ProcessInfo.processInfo.arguments.contains("-skipOnboarding") {
            return false
        }
        return !hasFinishedOnboarding
    }

    /// Appearance chosen in Settings.
    private var appearance: AppearanceChoice {
        AppearanceChoice(rawValue: appearanceRaw) ?? .system
    }
}
