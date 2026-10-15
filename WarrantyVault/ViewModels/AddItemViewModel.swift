//
//  AddItemViewModel.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  State for importing a receipt or typing a warranty by hand.
//

import Foundation
import Observation
import UIKit

/// Where the add flow should move next. The view performs the navigation.
enum AddStep: Equatable {
    /// Show the receipt and the scanning animation.
    case review
    /// Show the editable form.
    case form
}

/// Holds the receipt image, parsed fields, and the form that `WarrantyRepository` saves.
@MainActor
@Observable
final class AddItemViewModel {
    private let recognizer: any TextRecognizing
    private let parser: ReceiptParser
    private let suggester: CategorySuggester
    private let minimumReadDuration: Duration

    /// Downscaled receipt shown on the review screen. Nil for manual entry.
    var receiptImage: UIImage?
    /// JPEG bytes saved with the warranty. Nil for manual entry.
    private(set) var receiptJPEG: Data?
    /// Changes each time a new image starts scanning.
    var scanID = UUID()
    /// True while Photos or Files is being turned into an image.
    var isImporting = false
    /// True while OCR is running.
    var isReading = false
    /// True while the repository is saving.
    var isSaving = false
    /// Message when a file or photo cannot be used.
    var importError: String?
    /// Message when saving fails after the form was checked.
    var saveError: String?
    /// Message when OCR fails and the user should type the details.
    var readNotice: String?
    /// Lines read from the receipt, in the order the recognizer returned them.
    var recognizedLines: [String] = []
    /// Shown on the Add tab after a successful save.
    var savedMessage: String?
    /// Next screen the Add tab should open. The view clears this after navigating.
    var requestedStep: AddStep?

    /// Product name typed or read from the receipt.
    var productName = ""
    /// Shop or seller.
    var store = ""
    /// Day the product was purchased.
    var purchaseDate = Date.now
    /// Price as typed. The Rs. prefix is shown beside the field, not in this text.
    var amountText = ""
    /// Product group chosen by the user or suggested from the receipt.
    var category: ItemCategory = .other
    /// Selected cover length.
    var warrantyLength: WarrantyLengthOption = .twelve
    /// Months typed when `warrantyLength` is custom.
    var customMonths = ""
    /// Optional note stored with the warranty.
    var notes = ""

    /// Confidence from the parser. Nil after the user edits the field or on manual entry.
    var storeConfidence: ParseConfidence?
    /// Confidence of the parsed purchase date.
    var dateConfidence: ParseConfidence?
    /// Confidence of the parsed amount.
    var amountConfidence: ParseConfidence?
    /// Confidence of the suggested category.
    var categoryConfidence: ParseConfidence?
    /// Field messages shown when a save is not ready.
    var validation = AddItemValidation()

    /// Set while an existing warranty is being changed. Nil for a new item.
    private(set) var editingID: UUID?
    private var isApplyingParse = false

    /// Creates the flow. The bundled keyword list is used when `suggester` is omitted.
    init(
        recognizer: any TextRecognizing = OCRService(),
        parser: ReceiptParser = ReceiptParser(),
        suggester: CategorySuggester? = nil,
        minimumReadDuration: Duration = .milliseconds(800)
    ) {
        self.recognizer = recognizer
        self.parser = parser
        self.suggester = suggester ?? Self.loadedSuggester()
        self.minimumReadDuration = minimumReadDuration
    }

    /// True when the store field should be drawn in amber.
    var storeNeedsReview: Bool { needsReview(storeConfidence) }
    /// True when the date field should be drawn in amber.
    var dateNeedsReview: Bool { needsReview(dateConfidence) }
    /// True when the amount field should be drawn in amber.
    var amountNeedsReview: Bool { needsReview(amountConfidence) }
    /// True when the category field should be drawn in amber.
    var categoryNeedsReview: Bool { needsReview(categoryConfidence) }
    /// True when Save should update a warranty instead of creating one.
    var isEditing: Bool { editingID != nil }

    /// Opens a blank form and does not run OCR.
    func startManualEntry() {
        clearForm()
        receiptImage = nil
        receiptJPEG = nil
        readNotice = nil
        savedMessage = nil
        requestedStep = .form
    }

    #if DEBUG
    /// Downscales the bundled sample receipt and opens the scanning screen.
    func importBundledSample() async {
        isImporting = true
        importError = nil
        defer { isImporting = false }
        guard let data = SampleReceiptImage.pngData() else {
            importError = String(localized: "That photo could not be opened.")
            return
        }
        await beginScan(withFileData: data, emptyMessage: String(localized: "That photo could not be opened."))
    }
    #endif

    /// Loads a Photos picker item, downscales it, and opens the scanning screen.
    func importPhoto(_ item: PhotosImport) async {
        isImporting = true
        importError = nil
        defer { isImporting = false }
        do {
            guard let data = try await item.loadData() else {
                importError = String(localized: "That photo could not be opened.")
                return
            }
            await beginScan(withFileData: data, emptyMessage: String(localized: "That photo could not be opened."))
        } catch {
            importError = String(localized: "That photo could not be opened.")
        }
    }

    /// Loads a Files pick, including the first page of a PDF, and opens the scanning screen.
    func importFile(_ result: Result<[URL], Error>) async {
        isImporting = true
        importError = nil
        defer { isImporting = false }
        switch result {
        case .failure:
            importError = String(localized: "That file could not be opened.")
        case .success(let urls):
            guard let url = urls.first else {
                importError = String(localized: "Choose a photo or a PDF.")
                return
            }
            await importFile(at: url)
        }
    }

    /// Reads the chosen receipt, then asks the view to open the form.
    func readReceipt() async {
        guard let receiptImage else {
            requestedStep = .form
            return
        }
        let token = scanID
        isReading = true
        readNotice = nil
        let started = ContinuousClock.now
        defer { isReading = false }
        do {
            let lines = try await recognizer.recognizeText(in: receiptImage)
            guard token == scanID, !Task.isCancelled else {
                return
            }
            recognizedLines = lines.map(\.text)
            let parsed = parser.parse(lines)
            let suggestion = suggester.suggest(from: lines)
            apply(parsed, suggestion: suggestion)
        } catch {
            guard token == scanID, !Task.isCancelled else {
                return
            }
            readNotice = String(localized: "The receipt could not be read. Enter the details yourself.")
        }
        let elapsed = started.duration(to: .now)
        if elapsed < minimumReadDuration {
            do {
                try await Task.sleep(for: minimumReadDuration - elapsed)
            } catch {
                return
            }
        }
        guard token == scanID, !Task.isCancelled else {
            return
        }
        requestedStep = .form
    }

    /// Updates the store and clears the amber hint once the user types.
    func setStore(_ value: String) {
        store = value
        if !isApplyingParse {
            storeConfidence = nil
        }
    }

    /// Updates the purchase date and clears the amber hint once the user changes it.
    func setPurchaseDate(_ value: Date) {
        purchaseDate = value
        if !isApplyingParse {
            dateConfidence = nil
        }
    }

    /// Updates the amount text and clears the amber hint once the user types.
    func setAmountText(_ value: String) {
        amountText = value
        if !isApplyingParse {
            amountConfidence = nil
        }
    }

    /// Updates the category and clears the amber hint once the user picks one.
    func setCategory(_ value: ItemCategory) {
        category = value
        if !isApplyingParse {
            categoryConfidence = nil
        }
    }

    /// Fills the form from a saved warranty so it can be updated.
    func loadExisting(_ item: WarrantyItem) {
        clearForm()
        editingID = item.id
        productName = item.name
        store = item.store
        purchaseDate = item.purchaseDate
        amountText = AddItemRules.amountText(from: Decimal(item.amount))
        category = item.category
        notes = item.notes
        receiptJPEG = item.receiptImageData
        if let data = item.receiptImageData {
            receiptImage = UIImage(data: data)
        }
        switch item.warrantyMonths {
        case 6:
            warrantyLength = .six
        case 12:
            warrantyLength = .twelve
        case 24:
            warrantyLength = .twentyFour
        case 36:
            warrantyLength = .thirtySix
        default:
            warrantyLength = .custom
            customMonths = String(item.warrantyMonths)
        }
    }

    /// Checks the form, saves through `repository`, and replaces reminders when they are enabled.
    func save(
        using repository: WarrantyRepository?,
        reminders: (any WarrantyReminderScheduling)? = nil,
        preferences: ReminderPreferences = ReminderPreferences(),
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> Bool {
        savedMessage = nil
        saveError = nil
        validation = AddItemRules.validation(
            name: productName,
            amountText: amountText,
            length: warrantyLength,
            customMonths: customMonths
        )
        guard !validation.hasErrors else {
            SaveHaptic.notifyFailure()
            return false
        }
        guard let repository else {
            saveError = String(localized: "Warranty Vault could not open saved receipts.")
            SaveHaptic.notifyFailure()
            return false
        }
        guard let amount = AddItemRules.amount(from: amountText),
              let months = AddItemRules.months(length: warrantyLength, customMonths: customMonths) else {
            SaveHaptic.notifyFailure()
            return false
        }
        isSaving = true
        defer { isSaving = false }
        do {
            if let editingID {
                guard let existing = try repository.item(id: editingID) else {
                    saveError = String(localized: "This warranty is no longer in the vault.")
                    SaveHaptic.notifyFailure()
                    return false
                }
                try repository.update(
                    existing,
                    name: productName,
                    store: store,
                    purchaseDate: purchaseDate,
                    amount: amount,
                    warrantyMonths: months,
                    category: category,
                    notes: notes,
                    receiptImageData: receiptJPEG
                )
                await syncReminders(
                    for: existing,
                    reminders: reminders,
                    preferences: preferences,
                    now: now,
                    calendar: calendar
                )
                SaveHaptic.notifySuccess()
                savedMessage = String(localized: "Warranty updated.")
                return true
            }
            let created = try repository.create(
                name: productName,
                store: store,
                purchaseDate: purchaseDate,
                amount: amount,
                warrantyMonths: months,
                category: category,
                notes: notes,
                receiptImageData: receiptJPEG
            )
            await syncReminders(
                for: created,
                reminders: reminders,
                preferences: preferences,
                now: now,
                calendar: calendar
            )
            SaveHaptic.notifySuccess()
            clearForm()
            receiptImage = nil
            receiptJPEG = nil
            savedMessage = String(localized: "Warranty saved.")
            return true
        } catch let error as WarrantyRepositoryError {
            saveError = error.message
            SaveHaptic.notifyFailure()
            return false
        } catch {
            saveError = String(localized: "The warranty could not be saved.")
            SaveHaptic.notifyFailure()
            return false
        }
    }

    /// Replaces this warranty's reminders when the Settings toggle is on.
    private func syncReminders(
        for item: WarrantyItem,
        reminders: (any WarrantyReminderScheduling)?,
        preferences: ReminderPreferences,
        now: Date,
        calendar: Calendar
    ) async {
        guard let reminders, preferences.isEnabled else {
            return
        }
        await reminders.cancel(identifiers: WarrantyReminderPlan.identifiers(for: item.id))
        await reminders.schedule(
            WarrantyReminderPlan.reminders(for: item, now: now, calendar: calendar)
        )
    }

    /// Downscales the file off the main thread, then opens the scanning screen.
    private func beginScan(withFileData data: Data, emptyMessage: String) async {
        let jpeg = await Task.detached(priority: .userInitiated) {
            Self.preparedJPEG(from: data)
        }.value
        guard let jpeg, let image = UIImage(data: jpeg) else {
            importError = emptyMessage
            return
        }
        clearForm()
        receiptImage = image
        receiptJPEG = jpeg
        savedMessage = nil
        scanID = UUID()
        requestedStep = .review
    }

    /// Shrinks a photo or the first PDF page. Safe to call off the main thread.
    nonisolated private static func preparedJPEG(from data: Data) -> Data? {
        guard let image = ReceiptDocumentImage.image(from: data) else {
            return nil
        }
        return ReceiptImagePrep.downscaledJPEG(from: image)?.data
    }

    /// Reads a security-scoped file URL into an image.
    private func importFile(at url: URL) async {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let data = try await Task.detached {
                try Data(contentsOf: url)
            }.value
            await beginScan(withFileData: data, emptyMessage: String(localized: "Choose a photo or a PDF."))
        } catch {
            importError = String(localized: "That file could not be read.")
        }
    }

    /// Copies parser and suggester output into the form.
    private func apply(_ parsed: ParsedReceipt, suggestion: CategorySuggestion) {
        isApplyingParse = true
        setStore(parsed.storeName.value ?? "")
        storeConfidence = parsed.storeName.confidence
        setPurchaseDate(parsed.purchaseDate.value ?? .now)
        dateConfidence = parsed.purchaseDate.confidence
        if let amount = parsed.totalAmount.value {
            setAmountText(AddItemRules.amountText(from: amount))
        } else {
            setAmountText("")
        }
        amountConfidence = parsed.totalAmount.confidence
        setCategory(suggestion.category)
        categoryConfidence = suggestion.confidence
        isApplyingParse = false
    }

    /// Clears typed fields and review flags.
    private func clearForm() {
        productName = ""
        store = ""
        purchaseDate = .now
        amountText = ""
        category = .other
        warrantyLength = .twelve
        customMonths = ""
        notes = ""
        storeConfidence = nil
        dateConfidence = nil
        amountConfidence = nil
        categoryConfidence = nil
        validation = AddItemValidation()
        recognizedLines = []
        readNotice = nil
        importError = nil
        saveError = nil
        editingID = nil
    }

    /// Amber when the parser or suggester was not confident.
    private func needsReview(_ confidence: ParseConfidence?) -> Bool {
        confidence == .low || confidence == .missing
    }

    /// Loads the keyword file, or an empty list if that file is missing.
    private static func loadedSuggester() -> CategorySuggester {
        if let suggester = try? CategorySuggester() {
            return suggester
        }
        return CategorySuggester(keywords: [:])
    }
}

/// Photo bytes the add flow can load without importing PhotosUI into the view model.
protocol PhotosImport {
    /// Loads the picked photo as data.
    func loadData() async throws -> Data?
}
