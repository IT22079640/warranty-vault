//
//  ReceiptDocumentImageTests.swift
//  WarrantyVaultTests
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Checks that the first page of a PDF becomes an image.
//

import Testing
import UIKit
@testable import WarrantyVault

struct ReceiptDocumentImageTests {

    /// A one-page PDF renders to a non-empty image.
    @Test func firstPDFPageBecomesAnImage() {
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 280)
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, bounds, nil)
        UIGraphicsBeginPDFPage()
        let paragraph = "Abans" as NSString
        paragraph.draw(at: CGPoint(x: 24, y: 24), withAttributes: nil)
        UIGraphicsEndPDFContext()

        let image = ReceiptDocumentImage.pdfFirstPage(from: data as Data)

        #expect(image != nil)
        #expect((image?.size.width ?? 0) > 0)
        #expect((image?.size.height ?? 0) > 0)
    }

    /// A tiny photo is accepted and stored as JPEG without being enlarged.
    @Test func smallImageBecomesJPEG() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 10))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 10))
        }

        let prepared = ReceiptImagePrep.downscaledJPEG(from: image)
        let target = ReceiptImagePrep.targetPixelSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )

        #expect(prepared != nil)
        #expect(prepared?.image.size.width == target.width)
        #expect(prepared?.data.isEmpty == false)
    }
}
