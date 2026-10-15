//
//  AddItemViewModelTests.swift
//  WarrantyVaultTests
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Checks validation, receipt prefill, and saving through the repository.
//

import Foundation
import Testing
import UIKit
@testable import WarrantyVault

@MainActor
struct AddItemViewModelTests {

    /// Empty and invalid form values produce the messages the form shows.
    @Test func validationExplainsWhatToFix() {
        let empty = AddItemRules.validation(name: "  ", amountText: "", length: .twelve, customMonths: "")
        #expect(empty.productName == "Enter a product name.")
        #expect(empty.amount == "Enter the amount paid.")
        #expect(empty.warrantyLength == nil)

        let badAmount = AddItemRules.validation(name: "Kettle", amountText: "abc", length: .custom, customMonths: "")
        #expect(badAmount.amount == "Enter an amount such as 1500.00.")
        #expect(badAmount.warrantyLength == "Enter how many months the warranty lasts.")

        let negative = AddItemRules.validation(name: "Kettle", amountText: "-5", length: .custom, customMonths: "-2")
        #expect(negative.amount == "Amount cannot be negative.")
        #expect(negative.warrantyLength == "Warranty length cannot be negative.")
    }

    /// Prices with commas and Rs still parse, and presets map to months.
    @Test func amountAndLengthParsing() {
        #expect(AddItemRules.amount(from: "1,150.50") == Decimal(string: "1150.50"))
        #expect(AddItemRules.amount(from: "Rs 75.00") == Decimal(string: "75.00"))
        #expect(AddItemRules.months(length: .twentyFour, customMonths: "") == 24)
        #expect(AddItemRules.months(length: .custom, customMonths: "18") == 18)
        #expect(ReceiptImagePrep.targetPixelSize(width: 3200, height: 1600) == CGSize(width: 1600, height: 800))
        #expect(ReceiptImagePrep.targetPixelSize(width: 800, height: 600) == CGSize(width: 800, height: 600))
    }

    /// A low-confidence store stays highlighted until the parsed form is filled.
    @Test func readingAReceiptPrefillsUncertainFields() async {
        let model = AddItemViewModel(
            recognizer: FixedReceiptRecognizer(lines: [
                RecognizedLine(text: "Abans", confidence: 0.4, boundingBox: CGRect(x: 0, y: 0.9, width: 0.8, height: 0.04)),
                RecognizedLine(text: "Grand Total Rs 49.50", confidence: 0.95, boundingBox: CGRect(x: 0, y: 0.2, width: 0.8, height: 0.04))
            ]),
            parser: ReceiptParser(timeZone: TimeZone(secondsFromGMT: 0) ?? .gmt),
            suggester: CategorySuggester(keywords: [.appliance: ["kettle"]], embedding: nil),
            minimumReadDuration: .zero
        )
        model.receiptImage = UIImage()
        await model.readReceipt()

        #expect(model.store == "Abans")
        #expect(model.storeNeedsReview)
        #expect(AddItemRules.amount(from: model.amountText) == Decimal(string: "49.50"))
        #expect(model.amountNeedsReview == false)
        #expect(model.requestedStep == .form)
    }

    /// Manual entry does not mark fields as uncertain.
    @Test func manualEntrySkipsReviewHighlights() {
        let model = AddItemViewModel(
            recognizer: FixedReceiptRecognizer(lines: []),
            suggester: CategorySuggester(keywords: [:], embedding: nil),
            minimumReadDuration: .zero
        )
        model.startManualEntry()

        #expect(model.requestedStep == .form)
        #expect(model.storeNeedsReview == false)
        #expect(model.receiptImage == nil)
    }

    /// Save writes one warranty and rejects a blank name before touching the store.
    @Test func saveUsesTheRepository() throws {
        let repository = try WarrantyRepository(container: ModelContainerFactory.makePreviewContainer())
        let model = AddItemViewModel(
            recognizer: FixedReceiptRecognizer(lines: []),
            suggester: CategorySuggester(keywords: [:], embedding: nil),
            minimumReadDuration: .zero
        )
        model.productName = "Kettle"
        model.store = "Abans"
        model.amountText = "49.50"
        model.warrantyLength = .twelve
        model.category = .appliance

        #expect(model.save(using: repository))
        let saved = try repository.items()
        #expect(saved.count == 1)
        #expect(saved.first?.name == "Kettle")
        #expect(saved.first?.warrantyMonths == 12)
        #expect(model.savedMessage == "Warranty saved.")

        model.productName = " "
        model.amountText = "10"
        #expect(model.save(using: repository) == false)
        #expect(model.validation.productName == "Enter a product name.")
        #expect(try repository.items().count == 1)
    }

    /// Loading a saved warranty and saving again updates that record.
    @Test func saveUpdatesAnExistingWarranty() throws {
        let repository = try WarrantyRepository(container: ModelContainerFactory.makePreviewContainer())
        let created = try repository.create(
            name: "Kettle",
            store: "Abans",
            purchaseDate: .now,
            amount: 40,
            warrantyMonths: 12,
            category: .appliance
        )
        let model = AddItemViewModel(
            recognizer: FixedReceiptRecognizer(lines: []),
            suggester: CategorySuggester(keywords: [:], embedding: nil),
            minimumReadDuration: .zero
        )
        model.loadExisting(created)
        model.productName = "Desk lamp"
        model.store = "Softlogic"
        model.warrantyLength = .custom
        model.customMonths = "18"

        #expect(model.isEditing)
        #expect(model.save(using: repository))
        #expect(model.savedMessage == "Warranty updated.")
        #expect(try repository.items().count == 1)
        let updated = try repository.item(id: created.id)
        #expect(updated?.name == "Desk lamp")
        #expect(updated?.warrantyMonths == 18)
        #expect(model.isEditing)
    }
}

/// Recognizer double that returns prepared lines and ignores the image.
private struct FixedReceiptRecognizer: TextRecognizing {
    var lines: [RecognizedLine]

    /// Returns the canned lines.
    func recognizeText(in image: UIImage) async throws -> [RecognizedLine] {
        lines
    }
}
