//
//  WarrantyRepositoryTests.swift
//  WarrantyVaultTests
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Checks create, read, update, delete, search, sort, and filter.
//

import Foundation
import Testing
@testable import WarrantyVault

@MainActor
struct WarrantyRepositoryTests {

    private let calendar = Calendar(identifier: .gregorian)

    /// A saved warranty can be read back, including the receipt bytes.
    @Test func createAndFetchRoundTrip() throws {
        let repository = try makeRepository()
        let created = try repository.create(
            name: "  Kettle  ",
            store: " Abans ",
            purchaseDate: date(year: 2026, month: 1, day: 10),
            amount: Decimal(string: "49.50") ?? 0,
            warrantyMonths: 12,
            category: .appliance,
            notes: " Gift ",
            receiptImageData: Data([1, 2, 3])
        )

        let loaded = try repository.item(id: created.id)

        #expect(loaded?.name == "Kettle")
        #expect(loaded?.store == "Abans")
        #expect(loaded?.notes == "Gift")
        #expect(loaded?.receiptImageData == Data([1, 2, 3]))
        #expect(loaded?.category == .appliance)
        #expect(try repository.items().count == 1)
        #expect(try repository.items().first?.receiptImageData == Data([1, 2, 3]))
    }

    /// Blank names and negative values are rejected and nothing is saved.
    @Test func createRejectsInvalidFields() throws {
        let repository = try makeRepository()

        #expect(throws: WarrantyRepositoryError.emptyName) {
            try repository.create(
                name: "   ",
                store: "Shop",
                purchaseDate: .now,
                amount: 1,
                warrantyMonths: 12,
                category: .phone
            )
        }
        #expect(throws: WarrantyRepositoryError.negativeAmount) {
            try repository.create(
                name: "Phone",
                store: "Shop",
                purchaseDate: .now,
                amount: -1,
                warrantyMonths: 12,
                category: .phone
            )
        }
        #expect(throws: WarrantyRepositoryError.negativeWarrantyLength) {
            try repository.create(
                name: "Phone",
                store: "Shop",
                purchaseDate: .now,
                amount: 1,
                warrantyMonths: -2,
                category: .phone
            )
        }
        #expect(try repository.items(matching: WarrantyQuery(archiveScope: .all)).isEmpty)
    }

    /// Search matches name, store, notes, and category, and ignores case.
    @Test func searchMatchesSeveralFields() throws {
        let repository = try makeRepository()
        try insertFixtures(into: repository)

        let byName = try repository.items(matching: WarrantyQuery(searchText: "macbook"))
        let byStore = try repository.items(matching: WarrantyQuery(searchText: "SINGER"))
        let byNotes = try repository.items(matching: WarrantyQuery(searchText: "glove"))
        let byCategory = try repository.items(matching: WarrantyQuery(searchText: "vehicle"))

        #expect(byName.map(\.name) == ["MacBook Air"])
        #expect(byStore.map(\.name) == ["Washer"])
        #expect(byNotes.map(\.name) == ["Honda Fit"])
        #expect(byCategory.map(\.name) == ["Honda Fit"])
    }

    /// Category and status filters combine, and archived rows stay hidden by default.
    @Test func filtersByCategoryStatusAndArchive() throws {
        let repository = try makeRepository()
        let today = date(year: 2026, month: 10, day: 13)
        try insertFixtures(into: repository)
        let sofa = try #require(try repository.items(matching: WarrantyQuery(archiveScope: .archived)).first)

        let appliances = try repository.items(matching: WarrantyQuery(category: .appliance))
        let expired = try repository.items(
            matching: WarrantyQuery(status: .expired, referenceDate: today)
        )
        let activeDefault = try repository.items(matching: WarrantyQuery(referenceDate: today))

        #expect(appliances.map(\.name) == ["Washer"])
        #expect(expired.map(\.name) == ["Washer"])
        #expect(activeDefault.contains(where: { $0.id == sofa.id }) == false)
        #expect(sofa.isArchived)
    }

    /// Amount sort is descending when ascending is false, with a stable name tie-break unused here.
    @Test func sortsByAmountDescending() throws {
        let repository = try makeRepository()
        try insertFixtures(into: repository)

        let sorted = try repository.items(
            matching: WarrantyQuery(sort: .amount, ascending: false, referenceDate: date(year: 2026, month: 10, day: 13))
        )

        #expect(sorted.map(\.name) == ["Honda Fit", "MacBook Air", "Washer"])
    }

    /// Update changes stored fields, and delete removes the row.
    @Test func updateAndDelete() throws {
        let repository = try makeRepository()
        let created = try repository.create(
            name: "Lamp",
            store: "Abans",
            purchaseDate: date(year: 2026, month: 1, day: 1),
            amount: 20,
            warrantyMonths: 6,
            category: .other
        )

        try repository.update(
            created,
            name: "Desk lamp",
            store: "Softlogic",
            purchaseDate: date(year: 2026, month: 2, day: 1),
            amount: 35,
            warrantyMonths: 12,
            category: .furniture,
            notes: "Replacement",
            receiptImageData: Data([9])
        )
        let updated = try repository.item(id: created.id)
        #expect(updated?.name == "Desk lamp")
        #expect(updated?.store == "Softlogic")
        #expect(updated?.category == .furniture)
        #expect(updated?.receiptImageData == Data([9]))

        try repository.setArchived(created, isArchived: true)
        #expect(try repository.items().isEmpty)
        #expect(try repository.items(matching: WarrantyQuery(archiveScope: .archived)).count == 1)

        try repository.delete(created)
        #expect(try repository.item(id: created.id) == nil)
    }

    /// Preview seeds include an active item, one expiring soon, one expired, and one archived.
    @Test func sampleDataCoversEachStatus() throws {
        let today = date(year: 2026, month: 10, day: 13)
        let container = try WarrantySampleData.makePreviewContainer(on: today, calendar: calendar)
        let repository = WarrantyRepository(container: container)
        let visible = try repository.items(
            matching: WarrantyQuery(archiveScope: .all, referenceDate: today)
        )

        let statuses = Set(visible.filter { !$0.isArchived }.map { $0.status(on: today, calendar: calendar) })
        let hasArchivedItem = visible.contains { $0.isArchived }
        #expect(statuses == [.active, .expiringSoon, .expired])
        #expect(hasArchivedItem)
        #expect(visible.count == WarrantySampleData.seeds(on: today, calendar: calendar).count)
    }

    /// Opens a fresh in-memory store.
    private func makeRepository() throws -> WarrantyRepository {
        let container = try ModelContainerFactory.makePreviewContainer()
        return WarrantyRepository(container: container)
    }

    /// Inserts one active, one expiring, and one expired warranty.
    private func insertFixtures(into repository: WarrantyRepository) throws {
        let today = date(year: 2026, month: 10, day: 13)
        _ = try repository.create(
            name: "MacBook Air",
            store: "iShop",
            purchaseDate: today,
            amount: 1899,
            warrantyMonths: 24,
            category: .laptop,
            notes: ""
        )
        _ = try repository.create(
            name: "Washer",
            store: "Singer",
            purchaseDate: date(year: 2024, month: 8, day: 13),
            amount: 640,
            warrantyMonths: 12,
            category: .appliance,
            notes: ""
        )
        _ = try repository.create(
            name: "Honda Fit",
            store: "Stafford Motors",
            purchaseDate: today,
            amount: 12500,
            warrantyMonths: 36,
            category: .vehicle,
            notes: "Booklet in the glove box."
        )
        _ = try repository.create(
            name: "Sofa",
            store: "Damro",
            purchaseDate: today,
            amount: 450,
            warrantyMonths: 36,
            category: .furniture,
            notes: "",
            isArchived: true
        )
    }

    /// Makes a Gregorian date at midnight.
    private func date(year: Int, month: Int, day: Int) -> Date {
        var calendar = calendar
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        let components = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: year, month: month, day: day)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }
}
