//
//  WarrantyVaultApp.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi  on 2026-10-12.
//

import SwiftUI
import SwiftData

@main
struct WarrantyVaultApp: App {
    @State private var router = AppRouter()
    private let modelContainerResult: Result<ModelContainer, Error>

    init() {
        modelContainerResult = Result { try ModelContainerFactory.makeContainer() }
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
                    .modelContainer(container)
            case .failure:
                StorageUnavailableView()
            }
        }
    }
}
