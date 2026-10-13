//
//  ModelContainerFactory.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Creates the SwiftData store. The schema stays empty until domain models exist.
//

import SwiftData

/// Builds the app's SwiftData container and falls back to memory if the disk store cannot open.
enum ModelContainerFactory {

    /// Opens the on-disk store, then an in-memory store if that fails.
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([])
        do {
            let stored = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [stored])
        } catch {
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [memory])
        }
    }
}
