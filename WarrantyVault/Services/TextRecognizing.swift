//
//  TextRecognizing.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Protocol for on-device text recognition, so tests can supply lines without Vision.
//

import CoreGraphics
import UIKit

/// One line of text found on a receipt image.
struct RecognizedLine: Equatable, Sendable {
    /// Text of the line, as recognized.
    var text: String

    /// Vision confidence from 0 to 1. Higher means the line is more trustworthy.
    var confidence: Float

    /// Bounding box in Vision coordinates: origin at the bottom left, values from 0 to 1.
    var boundingBox: CGRect

    /// Creates a recognized line.
    init(text: String, confidence: Float, boundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

/// Failure while reading text from an image. This path never opens the camera.
enum TextRecognitionError: Error, Equatable {
    /// The image has no pixel buffer Vision can read.
    case unreadableImage
    /// Vision failed while scanning the image.
    case recognitionFailed(message: String)
}

/// Reads receipt text from an image the user already imported.
protocol TextRecognizing {
    /// Recognizes text lines, including confidence and position, from `image`.
    func recognizeText(in image: UIImage) async throws -> [RecognizedLine]
}
