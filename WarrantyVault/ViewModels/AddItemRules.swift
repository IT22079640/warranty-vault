//
//  AddItemRules.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Validation and warranty-length choices for the add form.
//

import Foundation

/// Preset cover lengths, plus a custom number of months.
enum WarrantyLengthOption: String, CaseIterable, Identifiable {
    case six
    case twelve
    case twentyFour
    case thirtySix
    case custom

    /// Stable picker identity.
    var id: String { rawValue }

    /// Label shown in the warranty picker.
    var title: String {
        switch self {
        case .six:
            String(localized: "6 months")
        case .twelve:
            String(localized: "12 months")
        case .twentyFour:
            String(localized: "24 months")
        case .thirtySix:
            String(localized: "36 months")
        case .custom:
            String(localized: "Custom")
        }
    }

    /// Months for a preset. Nil when the user must type a number.
    var presetMonths: Int? {
        switch self {
        case .six:
            6
        case .twelve:
            12
        case .twentyFour:
            24
        case .thirtySix:
            36
        case .custom:
            nil
        }
    }
}

/// Messages for fields that are not ready to save. Nil means that field is fine.
struct AddItemValidation: Equatable {
    var productName: String?
    var amount: String?
    var warrantyLength: String?

    /// True when at least one field needs a correction.
    var hasErrors: Bool {
        productName != nil || amount != nil || warrantyLength != nil
    }
}

/// Pure checks shared by the add form and its tests.
enum AddItemRules {

    /// Reads a price typed as `1500`, `1500.50`, or `1,500.50`.
    static func amount(from text: String) -> Decimal? {
        let stripped = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "Rs.", with: "")
            .replacingOccurrences(of: "Rs", with: "")
            .replacingOccurrences(of: "LKR", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stripped.isEmpty else {
            return nil
        }
        return Decimal(string: stripped, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Months that will be saved, or nil when custom text is not a whole number.
    static func months(length: WarrantyLengthOption, customMonths: String) -> Int? {
        if let preset = length.presetMonths {
            return preset
        }
        let trimmed = customMonths.trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(trimmed)
    }

    /// Field messages. Empty name, a bad price, and a bad custom length are rejected.
    static func validation(
        name: String,
        amountText: String,
        length: WarrantyLengthOption,
        customMonths: String
    ) -> AddItemValidation {
        var result = AddItemValidation()
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.productName = String(localized: "Enter a product name.")
        }
        if amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.amount = String(localized: "Enter the amount paid.")
        } else if let amount = amount(from: amountText) {
            if amount < 0 {
                result.amount = String(localized: "Amount cannot be negative.")
            }
        } else {
            result.amount = String(localized: "Enter an amount such as 1500.00.")
        }
        result.warrantyLength = warrantyMessage(length: length, customMonths: customMonths)
        return result
    }

    /// Message for the warranty picker, or nil when the length can be saved.
    private static func warrantyMessage(length: WarrantyLengthOption, customMonths: String) -> String? {
        guard length == .custom else {
            return nil
        }
        let trimmed = customMonths.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return String(localized: "Enter how many months the warranty lasts.")
        }
        guard let months = Int(trimmed) else {
            return String(localized: "Enter the warranty length in whole months.")
        }
        if months < 0 {
            return String(localized: "Warranty length cannot be negative.")
        }
        if months > 600 {
            return String(localized: "Enter a warranty length up to 600 months.")
        }
        return nil
    }

    /// Plain text for a parsed price, without thousands separators.
    static func amountText(from amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? NSDecimalNumber(decimal: amount).stringValue
    }
}
