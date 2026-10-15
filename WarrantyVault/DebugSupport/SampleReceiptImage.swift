//
//  SampleReceiptImage.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  DEBUG-only sample receipt for the screenshot tour. Release builds compile this file out.
//

import Foundation
import SwiftUI

#if DEBUG

/// Loads the bundled sample receipt when a UI test passes `-useSampleReceipt`.
enum SampleReceiptImage {
    /// Launch argument that skips Photos and Files and opens this image instead.
    static let launchArgument = "-useSampleReceipt"

    /// True when this process was started with `launchArgument`.
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// How long the scanning screen stays up so a UI test can photograph it.
    static var scanHold: Duration {
        isRequested ? .seconds(5) : .milliseconds(800)
    }

    /// Light or dark from `-AppleInterfaceStyle`, used when Settings is still on System.
    static var interfaceStyle: ColorScheme? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-AppleInterfaceStyle"),
              arguments.indices.contains(arguments.index(after: index)) else {
            return nil
        }
        switch arguments[arguments.index(after: index)] {
        case "Dark":
            return .dark
        case "Light":
            return .light
        default:
            return nil
        }
    }

    /// PNG bytes for `Resources/SampleReceipt.png`. Nil when the DEBUG copy step did not run.
    static func pngData() -> Data? {
        guard let url = Bundle.main.url(forResource: "SampleReceipt", withExtension: "png") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }
}
#endif
