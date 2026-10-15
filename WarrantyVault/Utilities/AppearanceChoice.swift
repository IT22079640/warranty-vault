//
//  AppearanceChoice.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  The appearance override stored from Settings.
//

import SwiftUI

/// Light, dark, or whatever the device is using.
enum AppearanceChoice: String, CaseIterable, Identifiable {
    /// UserDefaults key shared by the app shell and Settings.
    static let storageKey = "appearanceChoice"

    case system
    case light
    case dark

    /// Stable picker identity.
    var id: String { rawValue }

    /// Title shown in the appearance picker.
    var title: String {
        switch self {
        case .system:
            String(localized: "System")
        case .light:
            String(localized: "Light")
        case .dark:
            String(localized: "Dark")
        }
    }

    /// Color scheme to apply. Nil follows the device.
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}
