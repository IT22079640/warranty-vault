//
//  ReceiptDocumentImage.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Turns an imported photo or the first page of a PDF into an image.
//

import PDFKit
import UIKit

/// Builds a `UIImage` from a file the user picked in Photos or Files.
enum ReceiptDocumentImage {

    /// Uses the bytes as a photo, or draws the first PDF page when they are a document.
    static func image(from data: Data) -> UIImage? {
        if let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 {
            return image
        }
        return pdfFirstPage(from: data)
    }

    /// Renders page 1 of a PDF. Nil when the data is not a readable document.
    static func pdfFirstPage(from data: Data) -> UIImage? {
        guard let document = PDFDocument(data: data), let page = document.page(at: 0) else {
            return nil
        }
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else {
            return nil
        }
        let scale: CGFloat = 2
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.saveGState()
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
            context.cgContext.restoreGState()
        }
    }
}
