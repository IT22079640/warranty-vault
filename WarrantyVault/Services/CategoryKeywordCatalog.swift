//
//  CategoryKeywordCatalog.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Loads the product-keyword dictionary bundled with the app.
//

import Foundation

/// Failure while reading `CategoryKeywords.json`.
enum CategoryCatalogError: Error, Equatable {
    /// The JSON file is not in the app bundle.
    case missingResource
    /// The JSON file could not be decoded.
    case unreadable
}

/// Keyword lists used to suggest a product category from receipt text.
enum CategoryKeywordCatalog {
    /// Anchor so `Bundle(for:)` finds the app target that holds the JSON file.
    private final class Token {}

    /// Bundle that contains `CategoryKeywords.json`.
    static var bundle: Bundle {
        Bundle(for: Token.self)
    }

    /// Loads keywords keyed by category. Unknown JSON keys are ignored.
    static func load(from bundle: Bundle = CategoryKeywordCatalog.bundle) throws -> [ItemCategory: [String]] {
        guard let url = resourceURL(in: bundle) else {
            throw CategoryCatalogError.missingResource
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw CategoryCatalogError.unreadable
        }
        let decoded: [String: [String]]
        do {
            decoded = try JSONDecoder().decode([String: [String]].self, from: data)
        } catch {
            throw CategoryCatalogError.unreadable
        }
        var keywords: [ItemCategory: [String]] = [:]
        for (key, values) in decoded {
            guard let category = ItemCategory(rawValue: key) else {
                continue
            }
            keywords[category] = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        }
        return keywords
    }

    /// Finds the JSON at the bundle root or inside a Resources folder.
    private static func resourceURL(in bundle: Bundle) -> URL? {
        bundle.url(forResource: "CategoryKeywords", withExtension: "json")
            ?? bundle.url(forResource: "CategoryKeywords", withExtension: "json", subdirectory: "Resources")
    }
}
