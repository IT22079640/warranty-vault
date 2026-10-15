//
//  WarrantyCSV.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  Spreadsheet text for the warranties stored on this device.
//

import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// Builds a CSV file the Settings screen can share.
enum WarrantyCSV {

    /// Header and one row per warranty, including archived records.
    static func make(items: [WarrantyItem], on date: Date = .now, calendar: Calendar = .current) -> String {
        var lines = [header]
        let sorted = items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        for item in sorted {
            lines.append(row(for: item, on: date, calendar: calendar))
        }
        return lines.joined(separator: "\n")
    }

    /// Column titles in the first row.
    private static var header: String {
        [
            "Name",
            "Store",
            "Purchase Date",
            "Amount",
            "Warranty Months",
            "Expiry Date",
            "Category",
            "Status",
            "Notes",
            "Archived"
        ].joined(separator: ",")
    }

    /// One warranty encoded as CSV fields.
    private static func row(for item: WarrantyItem, on date: Date, calendar: Calendar) -> String {
        let purchase = isoDate(item.purchaseDate, calendar: calendar)
        let expiry = isoDate(item.expiryDate(using: calendar), calendar: calendar)
        let amount = AddItemRules.amountText(from: Decimal(item.amount))
        let fields = [
            item.name,
            item.store,
            purchase,
            amount,
            String(item.warrantyMonths),
            expiry,
            item.category.title,
            item.status(on: date, calendar: calendar).title,
            item.notes,
            item.isArchived ? "yes" : "no"
        ]
        return fields.map(escape).joined(separator: ",")
    }

    /// `yyyy-MM-dd` in `calendar`, so the file does not depend on the clock time.
    private static func isoDate(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Wraps a field in quotes when it contains a comma, quote, or line break.
    private static func escape(_ field: String) -> String {
        let needsQuotes = field.contains(",") || field.contains("\"") || field.contains("\n")
        guard needsQuotes else {
            return field
        }
        let doubled = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(doubled)\""
    }
}

/// CSV payload shared from Settings.
struct WarrantyCSVDocument: Transferable {
    var text: String

    /// Exports the text as a comma-separated file.
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { document in
            Data(document.text.utf8)
        }
    }
}
