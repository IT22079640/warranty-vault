//
//  ModelContainerFactory.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Creates the SwiftData store for warranty records.
//

import Foundation
import SwiftData

/// Builds the app's SwiftData container and falls back to memory if the disk store cannot open.
enum ModelContainerFactory {

    /// Schema registered with every container this factory opens.
    static let schema = Schema([WarrantyItem.self])

    /// Opens the on-disk store, then an in-memory store if that fails.
    static func makeContainer() throws -> ModelContainer {
        do {
            return try open(inMemory: false)
        } catch {
            return try open(inMemory: true)
        }
    }

    /// Opens an in-memory store for tests and SwiftUI previews.
    static func makePreviewContainer() throws -> ModelContainer {
        try open(inMemory: true)
    }

    /// Opens one store using the shared warranty schema.
    ///
    /// In-memory stores get a unique name so parallel tests do not share one container.
    private static func open(inMemory: Bool) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(
                "memory-\(UUID().uuidString)",
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
