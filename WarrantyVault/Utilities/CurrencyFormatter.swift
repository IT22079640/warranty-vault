//
//  CurrencyFormatter.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  One LKR format for every amount the app shows.
//

import Foundation

/// Formats Sri Lankan rupee amounts as `Rs. 129,900.00`.
enum CurrencyFormatter {
    /// Visible currency prefix beside an editable number.
    static let symbol = "Rs."

    /// Grouped rupees with two decimal places, for labels and the CSV file.
    static func string(from amount: Decimal) -> String {
        "\(symbol) \(number(from: amount))"
    }

    /// Spoken form so VoiceOver says rupees instead of the letters R and S.
    static func spoken(from amount: Decimal) -> String {
        "\(number(from: amount)) \(String(localized: "rupees"))"
    }

    /// Digits with grouping separators and exactly two decimal places.
    private static func number(from amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
    }
}
