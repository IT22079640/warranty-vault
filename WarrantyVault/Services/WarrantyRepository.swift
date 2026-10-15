//
//  WarrantyRepository.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  The only type that reads and writes warranty records.
//

import Foundation
import SwiftData
import SwiftUI

/// Which archived rows a vault query includes.
enum WarrantyArchiveScope: Equatable {
    /// Records still in the active vault.
    case unarchived
    /// Records the user has archived.
    case archived
    /// Both archived and active records.
    case all
}

/// Stored field used to order a warranty list.
enum WarrantySort: String, CaseIterable, Identifiable {
    case name
    case store
    case purchaseDate
    case expiryDate
    case amount
    case createdAt

    /// Stable identifier for a sort picker.
    var id: String { rawValue }

    /// Label shown beside the sort control.
    var title: String {
        switch self {
        case .name:
            "Name"
        case .store:
            "Store"
        case .purchaseDate:
            "Purchase date"
        case .expiryDate:
            "Expiry date"
        case .amount:
            "Amount"
        case .createdAt:
            "Date added"
        }
    }
}

/// Search text, filters, and sort order for a vault list.
struct WarrantyQuery: Equatable {
    /// Matches name, store, notes, and category title. Blank matches everything.
    var searchText: String = ""

    /// Limits the list to one product group. Nil keeps every category.
    var category: ItemCategory?

    /// Limits the list to one cover state. Nil keeps every state.
    var status: WarrantyStatus?

    /// Controls whether archived records are included.
    var archiveScope: WarrantyArchiveScope = .unarchived

    /// Field used to order the list.
    var sort: WarrantySort = .expiryDate

    /// True lists smaller or earlier values first.
    var ascending: Bool = true

    /// Date used when a status filter is applied. Defaults to the moment of the query.
    var referenceDate: Date = .now
}

/// Failure from a warranty write. Views can show `message` without reading the store.
enum WarrantyRepositoryError: Error, Equatable {
    /// The name was empty after trimming spaces.
    case emptyName
    /// The price was below zero.
    case negativeAmount
    /// The warranty length was below zero.
    case negativeWarrantyLength

    /// Sentence suitable for an alert.
    var message: String {
        switch self {
        case .emptyName:
            String(localized: "Enter a product name.")
        case .negativeAmount:
            String(localized: "Amount cannot be negative.")
        case .negativeWarrantyLength:
            String(localized: "Warranty length cannot be negative.")
        }
    }
}

/// Creates, reads, updates, and deletes `WarrantyItem` records.
///
/// Views call this type instead of using `ModelContext` themselves.
@MainActor
final class WarrantyRepository {
    /// Kept alive so the context stays valid after the caller releases its own container.
    private let container: ModelContainer
    private let context: ModelContext

    /// Uses the container's main context for every read and write.
    init(container: ModelContainer) {
        self.container = container
        self.context = container.mainContext
    }

    /// Inserts a new warranty and saves it.
    func create(
        name: String,
        store: String,
        purchaseDate: Date,
        amount: Decimal,
        warrantyMonths: Int,
        category: ItemCategory,
        notes: String = "",
        receiptImageData: Data? = nil,
        isArchived: Bool = false,
        createdAt: Date = .now
    ) throws -> WarrantyItem {
        let item = WarrantyItem(
            name: try validatedName(name),
            store: store.trimmingCharacters(in: .whitespacesAndNewlines),
            purchaseDate: purchaseDate,
            amount: try storedAmount(amount),
            warrantyMonths: try validatedMonths(warrantyMonths),
            category: category,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            receiptImageData: receiptImageData,
            isArchived: isArchived,
            createdAt: createdAt
        )
        context.insert(item)
        try context.save()
        return item
    }

    /// Returns the warranty with `id`, or nil when it is not in the store.
    func item(id: UUID) throws -> WarrantyItem? {
        let identifier = id
        let descriptor = FetchDescriptor<WarrantyItem>(
            predicate: #Predicate { $0.id == identifier }
        )
        return try context.fetch(descriptor).first
    }

    /// Returns warranties that match the search text, filters, and sort order.
    ///
    /// Archive state is applied in the store. Status and expiry are calculated,
    /// so those filters and that sort happen after the fetch.
    func items(matching query: WarrantyQuery = WarrantyQuery()) throws -> [WarrantyItem] {
        let descriptor = FetchDescriptor<WarrantyItem>(
            predicate: archivePredicate(for: query.archiveScope)
        )
        let stored = try context.fetch(descriptor)
        return refine(stored, with: query)
    }

    /// Replaces the editable fields of an existing warranty and saves.
    func update(
        _ item: WarrantyItem,
        name: String,
        store: String,
        purchaseDate: Date,
        amount: Decimal,
        warrantyMonths: Int,
        category: ItemCategory,
        notes: String,
        receiptImageData: Data?
    ) throws {
        item.name = try validatedName(name)
        item.store = store.trimmingCharacters(in: .whitespacesAndNewlines)
        item.purchaseDate = purchaseDate
        item.amount = try storedAmount(amount)
        item.warrantyMonths = try validatedMonths(warrantyMonths)
        item.category = category
        item.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        item.receiptImageData = receiptImageData
        try context.save()
    }

    /// Moves a warranty into or out of the archive and saves.
    func setArchived(_ item: WarrantyItem, isArchived: Bool) throws {
        item.isArchived = isArchived
        try context.save()
    }

    /// Removes a warranty and saves.
    func delete(_ item: WarrantyItem) throws {
        context.delete(item)
        try context.save()
    }

    /// Removes every warranty, archived or not, and saves.
    func deleteAll() throws {
        let items = try context.fetch(FetchDescriptor<WarrantyItem>())
        for item in items {
            context.delete(item)
        }
        try context.save()
    }

    /// Rejects a blank product name.
    private func validatedName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw WarrantyRepositoryError.emptyName
        }
        return trimmed
    }

    /// Rejects a price below zero and converts it to the stored number.
    private func storedAmount(_ amount: Decimal) throws -> Double {
        guard amount >= 0 else {
            throw WarrantyRepositoryError.negativeAmount
        }
        return NSDecimalNumber(decimal: amount).doubleValue
    }

    /// Rejects a warranty length below zero.
    private func validatedMonths(_ warrantyMonths: Int) throws -> Int {
        guard warrantyMonths >= 0 else {
            throw WarrantyRepositoryError.negativeWarrantyLength
        }
        return warrantyMonths
    }

    /// Builds the stored-archive predicate. Nil means both archived and active rows.
    private func archivePredicate(for scope: WarrantyArchiveScope) -> Predicate<WarrantyItem>? {
        switch scope {
        case .unarchived:
            return #Predicate { $0.isArchived == false }
        case .archived:
            return #Predicate { $0.isArchived == true }
        case .all:
            return nil
        }
    }

    /// Applies search, category, status, and sort to rows already loaded.
    private func refine(_ stored: [WarrantyItem], with query: WarrantyQuery) -> [WarrantyItem] {
        let needle = query.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = stored.filter { item in
            if let category = query.category, item.category != category {
                return false
            }
            if let status = query.status, item.status(on: query.referenceDate) != status {
                return false
            }
            if needle.isEmpty {
                return true
            }
            return item.name.localizedStandardContains(needle)
                || item.store.localizedStandardContains(needle)
                || item.notes.localizedStandardContains(needle)
                || item.category.title.localizedStandardContains(needle)
        }
        return filtered.sorted { lhs, rhs in
            compare(lhs, rhs, query: query)
        }
    }

    /// Orders two warranties by the requested field, then by name, then by id.
    private func compare(_ lhs: WarrantyItem, _ rhs: WarrantyItem, query: WarrantyQuery) -> Bool {
        let calendar = Calendar.current
        let result: ComparisonResult
        switch query.sort {
        case .name:
            result = lhs.name.localizedStandardCompare(rhs.name)
        case .store:
            result = lhs.store.localizedStandardCompare(rhs.store)
        case .purchaseDate:
            result = comparison(lhs.purchaseDate, rhs.purchaseDate)
        case .expiryDate:
            result = comparison(
                lhs.expiryDate(using: calendar),
                rhs.expiryDate(using: calendar)
            )
        case .amount:
            result = comparison(lhs.amount, rhs.amount)
        case .createdAt:
            result = comparison(lhs.createdAt, rhs.createdAt)
        }
        if result == .orderedSame {
            let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
            if nameOrder == .orderedSame {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return nameOrder == .orderedAscending
        }
        return query.ascending ? result == .orderedAscending : result == .orderedDescending
    }

    /// Compares two dates without treating them as equal when only the time differs for sort ties.
    private func comparison(_ lhs: Date, _ rhs: Date) -> ComparisonResult {
        if lhs == rhs {
            return .orderedSame
        }
        return lhs < rhs ? .orderedAscending : .orderedDescending
    }

    /// Compares two prices.
    private func comparison(_ lhs: Double, _ rhs: Double) -> ComparisonResult {
        if lhs == rhs {
            return .orderedSame
        }
        return lhs < rhs ? .orderedAscending : .orderedDescending
    }
}

/// Environment entry so screens can use the repository without a model context.
private struct WarrantyRepositoryKey: EnvironmentKey {
    static let defaultValue: WarrantyRepository? = nil
}

extension EnvironmentValues {
    /// Warranty store for the current scene. Nil only when the store failed to open.
    var warrantyRepository: WarrantyRepository? {
        get { self[WarrantyRepositoryKey.self] }
        set { self[WarrantyRepositoryKey.self] = newValue }
    }
}
