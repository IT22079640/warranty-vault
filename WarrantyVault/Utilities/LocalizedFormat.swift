//
//  LocalizedFormat.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  Looks up a format string in the String Catalog, then fills it in.
//

import Foundation

/// Formats a catalog string such as "%lld days left".
enum LocalizedFormat {

    /// Returns the localized template with `arguments` substituted for the current locale.
    static func string(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        let template = String(localized: key)
        return String(format: template, locale: .current, arguments: arguments)
    }
}
