//
//  WarrantyStatus.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Whether a warranty is still in force, close to ending, or finished.
//

import SwiftUI

/// Coverage state derived from the expiry date. It is not stored.
enum WarrantyStatus: String, CaseIterable, Identifiable {
    /// More than 30 days remain.
    case active
    /// The expiry date is today or within the next 30 days.
    case expiringSoon
    /// The expiry date is before today.
    case expired

    /// Days, including today, that still count as expiring soon.
    static let expiringSoonDayCount = 30

    /// Stable identifier for pickers and filters.
    var id: String { rawValue }

    /// Short label for lists and filters.
    var title: String {
        switch self {
        case .active:
            "Active"
        case .expiringSoon:
            "Expiring soon"
        case .expired:
            "Expired"
        }
    }

    /// SF Symbol that represents this state.
    var symbolName: String {
        switch self {
        case .active:
            "checkmark.seal"
        case .expiringSoon:
            "clock.badge.exclamationmark"
        case .expired:
            "xmark.seal"
        }
    }

    /// Tint used for the status icon. System colors adapt to Dark Mode.
    var color: Color {
        switch self {
        case .active:
            .green
        case .expiringSoon:
            Theme.Colors.amber
        case .expired:
            .red
        }
    }
}
