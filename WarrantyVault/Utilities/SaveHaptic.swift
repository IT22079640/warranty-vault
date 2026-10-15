//
//  SaveHaptic.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Save feedback that does nothing when the device has no haptic engine.
//

import CoreHaptics
import UIKit

/// Plays a short tap after save. The simulator reports no haptic hardware, so this stays silent there.
enum SaveHaptic {

    /// Success tap after a warranty is stored.
    static func notifySuccess() {
        notify(.success)
    }

    /// Error tap when save or validation fails.
    static func notifyFailure() {
        notify(.error)
    }

    /// Plays `kind` only when the hardware can actually vibrate.
    private static func notify(_ kind: UINotificationFeedbackGenerator.FeedbackType) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(kind)
    }
}
