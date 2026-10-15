//
//  ReceiptThumbnailCache.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  Keeps a small decoded receipt so list cells do not decode the JPEG on every refresh.
//

import UIKit

/// Decoded receipt thumbnails keyed by the warranty and the byte count.
enum ReceiptThumbnailCache {
    /// Longest side, in pixels, of a thumbnail drawn in the vault.
    static let maxPixelLength: CGFloat = 320

    private static let thumbnails = NSCache<NSString, UIImage>()

    /// A small image for `data`, reused when SwiftUI redraws the same card.
    static func thumbnail(id: UUID, data: Data) -> UIImage? {
        let key = cacheKey(id: id, byteCount: data.count)
        if let cached = thumbnails.object(forKey: key) {
            return cached
        }
        guard let image = UIImage(data: data) else {
            return nil
        }
        let small = scaled(image, maxLength: maxPixelLength) ?? image
        thumbnails.setObject(small, forKey: key)
        return small
    }

    /// Cache key that changes when the stored photo is replaced.
    private static func cacheKey(id: UUID, byteCount: Int) -> NSString {
        "\(id.uuidString)-\(byteCount)" as NSString
    }

    /// Draws `image` so its longest side is at most `maxLength` pixels.
    private static func scaled(_ image: UIImage, maxLength: CGFloat) -> UIImage? {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let target = ReceiptImagePrep.targetPixelSize(
            width: pixelWidth,
            height: pixelHeight,
            maxLength: maxLength
        )
        guard target.width >= 1, target.height >= 1 else {
            return nil
        }
        if target.width == pixelWidth, target.height == pixelHeight {
            return image
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
