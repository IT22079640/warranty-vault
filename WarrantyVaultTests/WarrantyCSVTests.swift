//
//  WarrantyCSVTests.swift
//  WarrantyVaultTests
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  Checks the shared spreadsheet and clearing the store.
//

import Foundation
import Testing
@testable import WarrantyVault

struct WarrantyCSVTests {

    /// A comma or quote in a field is escaped, and the header stays stable.
    @Test func csvEscapesCommasAndQuotes() {
        let item = WarrantyItem(
            name: "Desk, lamp",
            store: "Softlogic",
            purchaseDate: WarrantyReminderFixtures.date(year: 2026, month: 1, day: 2),
            amount: 35,
            warrantyMonths: 12,
            category: .furniture,
            notes: "He said \"gift\""
        )
        let csv = WarrantyCSV.make(
            items: [item],
            on: WarrantyReminderFixtures.date(year: 2026, month: 6, day: 1),
            calendar: WarrantyReminderFixtures.calendar
        )
        #expect(csv.hasPrefix("Name,Store,Purchase Date,Amount,Warranty Months,Expiry Date,Category,Status,Notes,Archived"))
        #expect(csv.contains("\"Desk, lamp\""))
        #expect(csv.contains("\"He said \"\"gift\"\"\""))
        #expect(csv.contains("2026-01-02"))
        #expect(csv.contains(",no"))
    }

    /// A line break is quoted, archived rows are marked, and names are sorted.
    @Test func csvSortsNamesAndQuotesNewlines() {
        let calendar = WarrantyReminderFixtures.calendar
        let on = WarrantyReminderFixtures.date(year: 2026, month: 6, day: 1)
        let lamp = WarrantyItem(
            name: "Lamp",
            store: "Abans",
            purchaseDate: WarrantyReminderFixtures.date(year: 2026, month: 1, day: 2),
            amount: 10,
            warrantyMonths: 12,
            category: .furniture,
            notes: "Line one\nLine two"
        )
        let archived = WarrantyItem(
            name: "Cable",
            store: "Softlogic",
            purchaseDate: WarrantyReminderFixtures.date(year: 2024, month: 1, day: 2),
            amount: 5,
            warrantyMonths: 1,
            category: .other,
            isArchived: true
        )
        let csv = WarrantyCSV.make(items: [lamp, archived], on: on, calendar: calendar)
        let cable = csv.range(of: "Cable,")
        let lampRange = csv.range(of: "Lamp,")
        #expect(cable != nil)
        #expect(lampRange != nil)
        if let cable, let lampRange {
            #expect(cable.lowerBound < lampRange.lowerBound)
        }
        #expect(csv.contains("\"Line one\nLine two\""))
        #expect(csv.contains(",yes"))
        #expect(csv.contains(",no"))
    }
}

@MainActor
struct WarrantyDataTests {

    /// Clear all removes archived and active warranties.
    @Test func deleteAllEmptiesTheStore() throws {
        let repository = try WarrantyRepository(container: ModelContainerFactory.makePreviewContainer())
        _ = try repository.create(
            name: "Kettle",
            store: "Abans",
            purchaseDate: .now,
            amount: 40,
            warrantyMonths: 12,
            category: .appliance
        )
        _ = try repository.create(
            name: "Sofa",
            store: "Damro",
            purchaseDate: .now,
            amount: 80,
            warrantyMonths: 12,
            category: .furniture,
            isArchived: true
        )
        try repository.deleteAll()
        #expect(try repository.items(matching: WarrantyQuery(archiveScope: .all)).isEmpty)
    }

    /// The appearance override maps onto a color scheme, and System does not force one.
    @Test func appearanceChoiceMapsTheColorScheme() {
        #expect(AppearanceChoice.system.colorScheme == nil)
        #expect(AppearanceChoice.light.colorScheme == .light)
        #expect(AppearanceChoice.dark.colorScheme == .dark)
    }

    /// Export includes archived warranties and stays empty when the store has none.
    @Test func exportCSVIncludesArchivedRows() throws {
        let repository = try WarrantyRepository(container: ModelContainerFactory.makePreviewContainer())
        let model = SettingsViewModel()
        let on = WarrantyReminderFixtures.date(year: 2026, month: 6, day: 1)
        #expect(model.exportCSV(using: repository, on: on, calendar: WarrantyReminderFixtures.calendar) == nil)

        _ = try repository.create(
            name: "Lamp",
            store: "Abans",
            purchaseDate: WarrantyReminderFixtures.date(year: 2026, month: 1, day: 2),
            amount: 10,
            warrantyMonths: 12,
            category: .furniture
        )
        _ = try repository.create(
            name: "Cable",
            store: "Softlogic",
            purchaseDate: WarrantyReminderFixtures.date(year: 2024, month: 1, day: 2),
            amount: 5,
            warrantyMonths: 1,
            category: .other,
            isArchived: true
        )
        let csv = model.exportCSV(using: repository, on: on, calendar: WarrantyReminderFixtures.calendar)
        #expect(csv?.contains("Lamp") == true)
        #expect(csv?.contains("Cable") == true)
        #expect(csv?.contains(",yes") == true)
    }
}
