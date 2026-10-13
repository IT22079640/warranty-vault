//
//  ModelContainerFactoryTests.swift
//  WarrantyVaultTests
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Confirms the empty SwiftData schema can open before domain models exist.
//

import Testing
@testable import WarrantyVault

struct ModelContainerFactoryTests {

    /// The store opens even though no domain models have been added yet.
    @Test func emptySchemaContainerOpens() throws {
        let container = try ModelContainerFactory.makeContainer()
        #expect(container.schema.entities.isEmpty)
    }
}
