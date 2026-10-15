//
//  WarrantySummary.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Days remaining, ring progress, and the text used by Share.
//

import Foundation

/// Calendar math and share text for one saved warranty.
enum WarrantySummary {

    /// Whole days from the start of `date` until the expiry day. Negative when cover has ended.
    static func daysRemaining(
        for item: WarrantyItem,
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: item.expiryDate(using: calendar))
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// Share of the cover period that is still ahead, from 0 when expired to 1 on the purchase day.
    static func coverProgress(
        for item: WarrantyItem,
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> Double {
        let purchase = calendar.startOfDay(for: item.purchaseDate)
        let expiry = calendar.startOfDay(for: item.expiryDate(using: calendar))
        let today = calendar.startOfDay(for: date)
        let total = calendar.dateComponents([.day], from: purchase, to: expiry).day ?? 0
        guard total > 0 else {
            return today <= expiry ? 1 : 0
        }
        let remaining = calendar.dateComponents([.day], from: today, to: expiry).day ?? 0
        return min(max(Double(remaining) / Double(total), 0), 1)
    }

    /// Short phrase for the ring and accessibility, such as "12 days left".
    static func daysLabel(_ days: Int) -> String {
        if days < 0 {
            let overdue = -days
            return overdue == 1 ? "1 day overdue" : "\(overdue) days overdue"
        }
        if days == 0 {
            return "Ends today"
        }
        if days == 1 {
            return "1 day left"
        }
        return "\(days) days left"
    }

    /// Plain-text summary suitable for the system share sheet.
    static func shareText(
        for item: WarrantyItem,
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        let purchased = item.purchaseDate.formatted(date: .abbreviated, time: .omitted)
        let expires = item.expiryDate(using: calendar).formatted(date: .abbreviated, time: .omitted)
        let amount = AddItemRules.amountText(from: Decimal(item.amount))
        let status = item.status(on: date, calendar: calendar)
        let days = daysRemaining(for: item, on: date, calendar: calendar)
        return """
        \(item.name)
        Store: \(item.store)
        Purchased: \(purchased)
        Amount: \(amount)
        Category: \(item.category.title)
        Warranty: \(item.warrantyMonths) months
        Expires: \(expires)
        Status: \(status.title)
        \(daysLabel(days))
        """
    }
}
