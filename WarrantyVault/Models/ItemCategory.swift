//
//  ItemCategory.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  The kind of product a warranty belongs to.
//

import SwiftUI

/// Product groups shown when a warranty is saved or filtered.
enum ItemCategory: String, CaseIterable, Codable, Identifiable {
    case phone
    case laptop
    case appliance
    case furniture
    case vehicle
    case other

    /// Stable identifier stored with the warranty.
    var id: String { rawValue }

    /// Name shown in pickers and search.
    var title: String {
        switch self {
        case .phone:
            String(localized: "Phone")
        case .laptop:
            String(localized: "Laptop")
        case .appliance:
            String(localized: "Appliance")
        case .furniture:
            String(localized: "Furniture")
        case .vehicle:
            String(localized: "Vehicle")
        case .other:
            String(localized: "Other")
        }
    }

    /// SF Symbol that represents this category.
    var symbolName: String {
        switch self {
        case .phone:
            "iphone"
        case .laptop:
            "laptopcomputer"
        case .appliance:
            "washer"
        case .furniture:
            "sofa"
        case .vehicle:
            "car"
        case .other:
            "shippingbox"
        }
    }

    /// Tint used for the category icon. System colors adapt to Dark Mode.
    var color: Color {
        switch self {
        case .phone:
            Theme.Colors.deepBlue
        case .laptop:
            .indigo
        case .appliance:
            Theme.Colors.amber
        case .furniture:
            .brown
        case .vehicle:
            .teal
        case .other:
            .gray
        }
    }
}
