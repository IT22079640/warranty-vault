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
    @State private var dismissedOnboarding = false
    @AppStorage(OnboardingStorage.finishedKey) private var hasFinishedOnboarding = false
    @AppStorage(AppearanceChoice.storageKey) private var appearanceRaw = AppearanceChoice.system.rawValue
    private let modelContainerResult: Result<ModelContainer, Error>
    private let reminderScheduler = UserNotificationReminderScheduler()
    private let notificationDelegate = ReminderNotificationDelegate()

    init() {
        if ProcessInfo.processInfo.arguments.contains("-resetOnboarding") {
            UserDefaults.standard.set(false, forKey: OnboardingStorage.finishedKey)
        }
        let result = Result { try ModelContainerFactory.makeContainer() }
        modelContainerResult = result
        if case .success(let container) = result {
            LaunchState.apply(to: container)
        }
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
                dismissedOnboarding = true
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
    ///
    /// `-resetOnboarding` shows it again for this launch. Dismissing it still saves the flag
    /// so the next launch, without that argument, opens the vault.
    private var showsOnboarding: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-skipOnboarding") || dismissedOnboarding {
            return false
        }
        if arguments.contains("-resetOnboarding") {
            return true
        }
        return !UserDefaults.standard.bool(forKey: OnboardingStorage.finishedKey)
    }

    /// Appearance chosen in Settings.
    private var appearance: AppearanceChoice {
        AppearanceChoice(rawValue: appearanceRaw) ?? .system
    }
}

/// Empties or seeds the store when a UI test passes `-resetVault` or `-seedVault`.
private enum LaunchState {

    /// Deletes saved warranties, then inserts the two rows the filter and delete tests expect.
    @MainActor
    static func apply(to container: ModelContainer) {
        let arguments = ProcessInfo.processInfo.arguments
        let shouldReset = arguments.contains("-resetVault") || arguments.contains("-seedVault")
        guard shouldReset else { return }
        let repository = WarrantyRepository(container: container)
        try? repository.deleteAll()
        guard arguments.contains("-seedVault") else { return }
        let calendar = Calendar.current
        let expiredPurchase = calendar.date(byAdding: .year, value: -3, to: .now) ?? .now
        try? repository.create(
            name: "Active Lamp",
            store: "Abans",
            purchaseDate: .now,
            amount: 80,
            warrantyMonths: 12,
            category: .furniture
        )
        try? repository.create(
            name: "Expired Fan",
            store: "Softlogic",
            purchaseDate: expiredPurchase,
            amount: 25,
            warrantyMonths: 6,
            category: .appliance
        )
    }
}
