//
//  WarrantySampleData.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Fixed warranties used by SwiftUI previews.
//

import Foundation
import SwiftData

/// Values for one preview warranty before it is inserted.
struct WarrantySeed: Equatable {
    var name: String
    var store: String
    var purchaseDate: Date
    var amount: Decimal
    var warrantyMonths: Int
    var category: ItemCategory
    var notes: String
    var isArchived: Bool
}

/// Preview records covering each category and each warranty state.
enum WarrantySampleData {

    /// Builds an in-memory store and fills it with `seeds`.
    @MainActor
    static func makePreviewContainer(
        on referenceDate: Date = .now,
        calendar: Calendar = .current
    ) throws -> ModelContainer {
        let container = try ModelContainerFactory.makePreviewContainer()
        let repository = WarrantyRepository(container: container)
        try load(into: repository, on: referenceDate, calendar: calendar)
        return container
    }

    /// Inserts every preview warranty through the repository.
    @MainActor
    static func load(
        into repository: WarrantyRepository,
        on referenceDate: Date = .now,
        calendar: Calendar = .current
    ) throws {
        for seed in seeds(on: referenceDate, calendar: calendar) {
            _ = try repository.create(
                name: seed.name,
                store: seed.store,
                purchaseDate: seed.purchaseDate,
                amount: seed.amount,
                warrantyMonths: seed.warrantyMonths,
                category: seed.category,
                notes: seed.notes,
                receiptImageData: seed.category == .phone ? Data([0xFF, 0xD8, 0xFF]) : nil,
                isArchived: seed.isArchived,
                createdAt: referenceDate
            )
        }
    }

    /// Preview rows dated from `referenceDate` so each cover state stays valid.
    static func seeds(on referenceDate: Date, calendar: Calendar = .current) -> [WarrantySeed] {
        let today = calendar.startOfDay(for: referenceDate)
        let recent = calendar.date(byAdding: .day, value: -20, to: today) ?? today
        let old = calendar.date(byAdding: .month, value: -14, to: today) ?? today
        return [
            WarrantySeed(
                name: "iPhone 15",
                store: "Apple Store",
                purchaseDate: today,
                amount: Decimal(string: "1299.00") ?? 1299,
                warrantyMonths: 24,
                category: .phone,
                notes: "Includes the box and charger.",
                isArchived: false
            ),
            WarrantySeed(
                name: "MacBook Air",
                store: "iShop",
                purchaseDate: recent,
                amount: Decimal(string: "1899.00") ?? 1899,
                warrantyMonths: 1,
                category: .laptop,
                notes: "Student discount applied.",
                isArchived: false
            ),
            WarrantySeed(
                name: "Front-load washer",
                store: "Singer",
                purchaseDate: old,
                amount: Decimal(string: "640.00") ?? 640,
                warrantyMonths: 12,
                category: .appliance,
                notes: "",
                isArchived: false
            ),
            WarrantySeed(
                name: "Sofa",
                store: "Damro",
                purchaseDate: today,
                amount: Decimal(string: "450.00") ?? 450,
                warrantyMonths: 36,
                category: .furniture,
                notes: "Replaced last year.",
                isArchived: true
            ),
            WarrantySeed(
                name: "Honda Fit",
                store: "Stafford Motors",
                purchaseDate: today,
                amount: Decimal(string: "12500.00") ?? 12500,
                warrantyMonths: 36,
                category: .vehicle,
                notes: "Service booklet is in the glove box.",
                isArchived: false
            ),
            WarrantySeed(
                name: "Desk lamp",
                store: "Abans",
                purchaseDate: today,
                amount: Decimal(string: "35.00") ?? 35,
                warrantyMonths: 6,
                category: .other,
                notes: "",
                isArchived: false
            )
        ]
    }
}
