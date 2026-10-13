//
//  OCRService.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  On-device text recognition using Vision. No camera and no VisionKit.
//

import UIKit
import Vision

/// Recognizes receipt text with `VNRecognizeTextRequest` off the main thread.
struct OCRService: TextRecognizing {

    /// Scans `image` in accurate mode with language correction turned on.
    func recognizeText(in image: UIImage) async throws -> [RecognizedLine] {
        let prepared = try prepare(image)
        return try await Task.detached(priority: .userInitiated) {
            try Self.recognize(prepared)
        }.value
    }

    /// Copies pixels and orientation before leaving the caller thread.
    private func prepare(_ image: UIImage) throws -> PreparedImage {
        guard image.size.width > 0, image.size.height > 0 else {
            throw TextRecognitionError.unreadableImage
        }
        guard let cgImage = renderedCGImage(from: image) else {
            throw TextRecognitionError.unreadableImage
        }
        return PreparedImage(
            cgImage: cgImage,
            orientation: CGImagePropertyOrientation(image.imageOrientation)
        )
    }

    /// Draws `image` into a `CGImage` when it is not already backed by one.
    private func renderedCGImage(from image: UIImage) -> CGImage? {
        if let cgImage = image.cgImage {
            return cgImage
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale > 0 ? image.scale : 1
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }.cgImage
    }

    /// Runs the Vision request. Call this only from a background task.
    private static func recognize(_ prepared: PreparedImage) throws -> [RecognizedLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(
            cgImage: prepared.cgImage,
            orientation: prepared.orientation,
            options: [:]
        )
        do {
            try handler.perform([request])
        } catch {
            throw TextRecognitionError.recognitionFailed(message: error.localizedDescription)
        }
        let observations = request.results ?? []
        return observations.compactMap(line(from:)).sorted(by: isAbove)
    }

    /// Maps one Vision observation to a line, using its best text candidate.
    private static func line(from observation: VNRecognizedTextObservation) -> RecognizedLine? {
        guard let candidate = observation.topCandidates(1).first else {
            return nil
        }
        let trimmed = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return RecognizedLine(
            text: trimmed,
            confidence: candidate.confidence,
            boundingBox: observation.boundingBox
        )
    }

    /// Orders lines from the top of the page to the bottom.
    private static func isAbove(_ lhs: RecognizedLine, _ rhs: RecognizedLine) -> Bool {
        if lhs.boundingBox.midY == rhs.boundingBox.midY {
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
        return lhs.boundingBox.midY > rhs.boundingBox.midY
    }
}

/// Pixels handed to Vision on a background task.
private struct PreparedImage: @unchecked Sendable {
    /// Image pixels. `CGImage` is immutable, so sharing it across the task is safe.
    let cgImage: CGImage
    /// How the pixels should be rotated before recognition.
    let orientation: CGImagePropertyOrientation
}

private extension CGImagePropertyOrientation {

    /// Converts a UIKit image orientation into the value Vision expects.
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .down:
            self = .down
        case .left:
            self = .left
        case .right:
            self = .right
        case .upMirrored:
            self = .upMirrored
        case .downMirrored:
            self = .downMirrored
        case .leftMirrored:
            self = .leftMirrored
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
