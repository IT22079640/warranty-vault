//
//  ParsedReceipt.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Fields extracted from a receipt, each marked so the UI can flag uncertain ones.
//

import Foundation

/// How much the parser trusts a single extracted field.
enum ParseConfidence: String, Equatable, Sendable {
    /// Safe to fill in without a warning.
    case high
    /// A value was found, but the user should check it.
    case low
    /// Nothing usable was found.
    case missing
}

/// A parsed value plus the flag the form should display.
struct ParsedField<Value: Equatable>: Equatable {
    /// Extracted value. Nil when `confidence` is `.missing`.
    var value: Value?
    /// Whether the UI should highlight this field.
    var confidence: ParseConfidence

    /// Creates a field. Missing confidence clears the value.
    init(value: Value?, confidence: ParseConfidence) {
        if confidence == .missing {
            self.value = nil
            self.confidence = .missing
        } else {
            self.value = value
            self.confidence = confidence
        }
    }
}

/// Store, date, and total read from recognized receipt lines.
struct ParsedReceipt: Equatable {
    /// Merchant name, usually the first real line at the top of the receipt.
    var storeName: ParsedField<String>
    /// Purchase date. Day-first when the receipt uses a numeric date.
    var purchaseDate: ParsedField<Date>
    /// Amount most likely to be the amount paid.
    var totalAmount: ParsedField<Decimal>
}
