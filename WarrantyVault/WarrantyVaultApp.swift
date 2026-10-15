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
    private let modelContainerResult: Result<ModelContainer, Error>
    private let reminderScheduler = UserNotificationReminderScheduler()
    private let notificationDelegate = ReminderNotificationDelegate()

    init() {
        modelContainerResult = Result { try ModelContainerFactory.makeContainer() }
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
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
}
