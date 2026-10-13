//
//  ModelContainerFactoryTests.swift
//  WarrantyVaultTests
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Confirms the warranty schema is registered and can open.
//

import Testing
@testable import WarrantyVault

struct ModelContainerFactoryTests {

    /// The app container opens with WarrantyItem as its only model.
    @Test func schemaRegistersWarrantyItem() throws {
        let container = try ModelContainerFactory.makeContainer()
        let names = container.schema.entities.map(\.name)

        #expect(names == ["WarrantyItem"])
    }

    /// Previews and tests can open a separate in-memory store with the same schema.
    @Test func previewContainerUsesTheSameSchema() throws {
        let container = try ModelContainerFactory.makePreviewContainer()
        let names = container.schema.entities.map(\.name)

        #expect(names == ["WarrantyItem"])
    }
}
