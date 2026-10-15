//
//  VaultViewModelTests.swift
//  WarrantyVaultTests
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Checks vault filters, archive, and delete.
//

import Foundation
import Testing
@testable import WarrantyVault

@MainActor
struct VaultViewModelTests {

    /// Each chip maps to the matching status, and All leaves status open.
    @Test func filtersBuildTheQuery() {
        let model = VaultViewModel()
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        model.searchText = "kettle"

        #expect(model.query(on: today).status == nil)
        #expect(model.query(on: today).searchText == "kettle")
        #expect(model.query(on: today).archiveScope == .unarchived)

        model.filter = .expiringSoon
        #expect(model.query(on: today).status == .expiringSoon)
        model.filter = .expired
        #expect(model.query(on: today).status == .expired)
        model.filter = .active
        #expect(model.query(on: today).status == .active)
    }

    /// Archive hides a warranty from the vault, and delete removes it.
    @Test func archiveAndDeleteChangeTheList() async throws {
        let repository = try WarrantyRepository(container: ModelContainerFactory.makePreviewContainer())
        let created = try repository.create(
            name: "Kettle",
            store: "Abans",
            purchaseDate: .now,
            amount: 40,
            warrantyMonths: 12,
            category: .appliance
        )
        let model = VaultViewModel()
        model.reload(using: repository)
        #expect(model.items.count == 1)
        #expect(model.showsFirstUseEmptyState == false)

        await model.archive(created, using: repository)
        #expect(model.items.isEmpty)
        #expect(model.showsFirstUseEmptyState)
        #expect(try repository.items(matching: WarrantyQuery(archiveScope: .archived)).count == 1)

        model.searchText = "missing"
        model.reload(using: repository)
        #expect(model.showsFirstUseEmptyState == false)

        model.searchText = ""
        model.filter = .all
        let second = try repository.create(
            name: "Lamp",
            store: "Softlogic",
            purchaseDate: .now,
            amount: 20,
            warrantyMonths: 6,
            category: .furniture
        )
        model.reload(using: repository)
        await model.delete(second, using: repository)
        #expect(model.items.isEmpty)
        #expect(try repository.item(id: second.id) == nil)
    }
}
