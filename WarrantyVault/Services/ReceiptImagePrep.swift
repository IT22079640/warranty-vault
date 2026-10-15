//
//  ReceiptImagePrep.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Shrinks a receipt photo before OCR and before it is stored.
//

import UIKit

/// Downscales receipt images so recognition and storage stay reasonably small.
enum ReceiptImagePrep {
    /// Longest side, in pixels, kept for OCR and the saved JPEG.
    static let maxPixelLength: CGFloat = 1600
    /// JPEG quality used for the stored receipt.
    static let jpegQuality: CGFloat = 0.7

    /// Pixel size that fits inside `maxLength` without enlarging a smaller image.
    static func targetPixelSize(width: CGFloat, height: CGFloat, maxLength: CGFloat = maxPixelLength) -> CGSize {
        guard width > 0, height > 0, maxLength > 0 else {
            return .zero
        }
        let longest = max(width, height)
        guard longest > maxLength else {
            return CGSize(width: width, height: height)
        }
        let scale = maxLength / longest
        return CGSize(width: (width * scale).rounded(.towardZero), height: (height * scale).rounded(.towardZero))
    }

    /// Returns a smaller image and its JPEG bytes. Nil when the image has no pixels.
    static func downscaledJPEG(from image: UIImage) -> (image: UIImage, data: Data)? {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let target = targetPixelSize(width: pixelWidth, height: pixelHeight)
        guard target.width >= 1, target.height >= 1 else {
            return nil
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let data = rendered.jpegData(compressionQuality: jpegQuality) else {
            return nil
        }
        return (rendered, data)
    }
}
