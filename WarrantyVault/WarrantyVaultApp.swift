//
//  WarrantyVaultApp.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi  on 2026-10-12.
//
//  App entry point, onboarding gate, and UI-test launch arguments.
//

import SwiftUI
import SwiftData
import UserNotifications

/// Creates the store, reminder scheduler, and the first screen.
@main
struct WarrantyVaultApp: App {
    @State private var router = AppRouter()
    @State private var dismissedOnboarding = false
    @AppStorage(OnboardingStorage.finishedKey) private var hasFinishedOnboarding = false
    @AppStorage(AppearanceChoice.storageKey) private var appearanceRaw = AppearanceChoice.system.rawValue
    private let modelContainerResult: Result<ModelContainer, Error>
    private let reminderScheduler = UserNotificationReminderScheduler()
    private let notificationDelegate = ReminderNotificationDelegate()

    /// Opens the store and applies UI-test launch arguments before the first frame.
    init() {
        if ProcessInfo.processInfo.arguments.contains("-resetOnboarding") {
            UserDefaults.standard.set(false, forKey: OnboardingStorage.finishedKey)
        }
        #if DEBUG
        if SampleReceiptImage.isRequested {
            UserDefaults.standard.removeObject(forKey: AppearanceChoice.storageKey)
        }
        #endif
        let result = Result { try ModelContainerFactory.makeContainer() }
        modelContainerResult = result
        if case .success(let container) = result {
            LaunchState.apply(to: container)
        }
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            themedRoot
        }
    }

    /// Applies the Settings appearance. A system choice normally follows the device.
    ///
    /// With `-useSampleReceipt`, a system choice follows `-AppleInterfaceStyle` so the
    /// screenshot tour can force light or dark. Release builds always apply the stored choice.
    @ViewBuilder
    private var themedRoot: some View {
        #if DEBUG
        if SampleReceiptImage.isRequested {
            root.preferredColorScheme(appearance.colorScheme ?? SampleReceiptImage.interfaceStyle)
        } else {
            root.preferredColorScheme(appearance.colorScheme)
        }
        #else
        root.preferredColorScheme(appearance.colorScheme)
        #endif
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
    ///
    /// `-useSampleReceipt` starts from the system setting so `-AppleInterfaceStyle` can drive the tour.
    private var appearance: AppearanceChoice {
        #if DEBUG
        if SampleReceiptImage.isRequested {
            _ = appearanceRaw
            let stored = UserDefaults.standard.string(forKey: AppearanceChoice.storageKey)
            return AppearanceChoice(rawValue: stored ?? "") ?? .system
        }
        #endif
        return AppearanceChoice(rawValue: appearanceRaw) ?? .system
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
        #if DEBUG
        let sampleReceipt = SampleReceiptImage.isRequested ? SampleReceiptImage.pngData() : nil
        #else
        let sampleReceipt: Data? = nil
        #endif
        try? repository.create(
            name: "Active Lamp",
            store: "Abans",
            purchaseDate: .now,
            amount: 80,
            warrantyMonths: 12,
            category: .furniture,
            receiptImageData: sampleReceipt
        )
        try? repository.create(
            name: "Expired Fan",
            store: "Softlogic",
            purchaseDate: expiredPurchase,
            amount: 25,
            warrantyMonths: 6,
            category: .appliance,
            receiptImageData: sampleReceipt
        )
    }
}
