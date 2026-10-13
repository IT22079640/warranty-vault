//
//  ReceiptParserTests.swift
//  WarrantyVaultTests
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Covers store, date, and total extraction across receipt formats.
//

import Foundation
import Testing
import UIKit
@testable import WarrantyVault

struct ReceiptParserTests {
    private let parser = ReceiptParser(timeZone: TimeZone(secondsFromGMT: 0) ?? .gmt)

    /// Day-first and month-name dates all land on the same calendar day.
    @Test(arguments: dateSamples)
    func parsesSupportedDateFormats(sample: DateSample) {
        let parsed = parser.parse([
            line("Abans", y: 0.9),
            line(sample.text, y: 0.7),
            line("Grand Total Rs 10.00", y: 0.2)
        ])
        let parts = dayParts(parsed.purchaseDate.value)

        #expect(parts.year == sample.year)
        #expect(parts.month == sample.month)
        #expect(parts.day == sample.day)
        #expect(parsed.purchaseDate.confidence == sample.confidence)
    }

    /// A labeled invoice date wins over a later warranty date.
    @Test func invoiceDateBeatsWarrantyDate() {
        let parsed = parser.parse([
            line("Abans", y: 0.9),
            line("Warranty expiry 01/01/2028", y: 0.6),
            line("Invoice date 13/10/2026", y: 0.75)
        ])
        let parts = dayParts(parsed.purchaseDate.value)

        #expect(parts.year == 2026)
        #expect(parts.month == 10)
        #expect(parts.day == 13)
        #expect(parsed.purchaseDate.confidence == .high)
    }

    /// Two unlabeled dates stay uncertain, and the higher line is kept.
    @Test func competingUnlabeledDatesAreLowConfidence() {
        let parsed = parser.parse([
            line("13/10/2026", y: 0.8),
            line("01/01/2027", y: 0.4)
        ])
        let parts = dayParts(parsed.purchaseDate.value)

        #expect(parts.year == 2026)
        #expect(parts.month == 10)
        #expect(parts.day == 13)
        #expect(parsed.purchaseDate.confidence == .low)
    }

    /// Impossible days are ignored.
    @Test(arguments: ["32/01/2026", "31/02/2026", "13/13/2026"])
    func rejectsImpossibleDates(text: String) {
        let parsed = parser.parse([
            line("Abans", y: 0.9),
            line(text, y: 0.5)
        ])

        #expect(parsed.purchaseDate.value == nil)
        #expect(parsed.purchaseDate.confidence == .missing)
    }

    /// An expiry date with no purchase date is returned as uncertain.
    @Test func expiryOnlyDateIsLowConfidence() {
        let parsed = parser.parse([
            line("Abans", y: 0.9),
            line("Valid until 01/06/2027", y: 0.4)
        ])
        let parts = dayParts(parsed.purchaseDate.value)

        #expect(parts.year == 2027)
        #expect(parts.month == 6)
        #expect(parts.day == 1)
        #expect(parsed.purchaseDate.confidence == .low)
    }

    /// Keyword totals beat subtotals, quantities, and bare currency lines.
    @Test(arguments: amountSamples)
    func parsesLikelyTotals(sample: AmountSample) {
        let parsed = parser.parse(sample.lines.map { line($0.text, y: $0.y) })

        #expect(parsed.totalAmount.value == sample.expected)
        #expect(parsed.totalAmount.confidence == sample.confidence)
    }

    /// The shop name is the first real line at the top, even if the array is bottom-first.
    @Test func storeNameUsesTheTopOfTheReceipt() {
        let parsed = parser.parse([
            line("Grand Total Rs 10.00", y: 0.1),
            line("No. 12 Galle Road", y: 0.7),
            line("TAX INVOICE", y: 0.95),
            line("Abans", y: 0.88),
            line("0112345678", y: 0.8)
        ])

        #expect(parsed.storeName.value == "Abans")
        #expect(parsed.storeName.confidence == .high)
    }

    /// A faint top line is kept, but flagged so the form can highlight it.
    @Test func faintStoreNameIsLowConfidence() {
        let parsed = parser.parse([
            line("Softlogic", y: 0.9, confidence: 0.4)
        ])

        #expect(parsed.storeName.value == "Softlogic")
        #expect(parsed.storeName.confidence == .low)
    }

    /// Blank input leaves every field missing.
    @Test func emptyReceiptHasNoFields() {
        let parsed = parser.parse([])

        #expect(parsed.storeName.confidence == .missing)
        #expect(parsed.purchaseDate.confidence == .missing)
        #expect(parsed.totalAmount.confidence == .missing)
    }

    /// A mock recognizer can feed the parser without Vision or a camera.
    @Test func parserReadsLinesFromAMockRecognizer() async throws {
        let recognizer = FixedTextRecognizer(lines: [
            line("Singer", y: 0.9),
            line("Date: 13-10-2026", y: 0.7),
            line("Grand Total LKR 640.00", y: 0.2)
        ])
        let recognized = try await recognizer.recognizeText(in: UIImage())
        let parsed = parser.parse(recognized)

        #expect(parsed.storeName.value == "Singer")
        #expect(dayParts(parsed.purchaseDate.value).month == 10)
        #expect(parsed.totalAmount.value == Decimal(string: "640.00"))
        #expect(parsed.totalAmount.confidence == .high)
    }

    /// Builds a line whose vertical position uses Vision's bottom-left origin.
    private func line(_ text: String, y: CGFloat, confidence: Float = 0.95) -> RecognizedLine {
        RecognizedLine(
            text: text,
            confidence: confidence,
            boundingBox: CGRect(x: 0.1, y: y, width: 0.8, height: 0.03)
        )
    }

    /// Reads the calendar day in the same time zone the parser uses.
    private func dayParts(_ date: Date?) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        guard let date else {
            return DateComponents()
        }
        return calendar.dateComponents([.year, .month, .day], from: date)
    }
}

/// One date string the parser should understand.
struct DateSample: Sendable {
    var text: String
    var year: Int
    var month: Int
    var day: Int
    var confidence: ParseConfidence
}

/// One total layout the parser should understand.
struct AmountSample: Sendable {
    var lines: [SampleLine]
    var expected: Decimal?
    var confidence: ParseConfidence
}

/// A receipt line placed on the page for an amount sample.
struct SampleLine: Sendable {
    var text: String
    var y: CGFloat
}

/// Date strings covering the supported numeric and month-name formats.
private let dateSamples: [DateSample] = [
    DateSample(text: "13/10/2026", year: 2026, month: 10, day: 13, confidence: .high),
    DateSample(text: "03/04/2026", year: 2026, month: 4, day: 3, confidence: .high),
    DateSample(text: "5/10/2026", year: 2026, month: 10, day: 5, confidence: .high),
    DateSample(text: "Date: 13/10/2026 14:30", year: 2026, month: 10, day: 13, confidence: .high),
    DateSample(text: "13-10-2026", year: 2026, month: 10, day: 13, confidence: .high),
    DateSample(text: "13 Oct 2026", year: 2026, month: 10, day: 13, confidence: .high),
    DateSample(text: "13 oct 2026", year: 2026, month: 10, day: 13, confidence: .high),
    DateSample(text: "13 October 2026", year: 2026, month: 10, day: 13, confidence: .high),
    DateSample(text: "2026-10-13", year: 2026, month: 10, day: 13, confidence: .high)
]

/// Amount strings covering Sri Lankan currency labels and total keywords.
private let amountSamples: [AmountSample] = [
    AmountSample(
        lines: [
            SampleLine(text: "Subtotal 1,000.00", y: 0.4),
            SampleLine(text: "Grand Total Rs 1,150.00", y: 0.2)
        ],
        expected: Decimal(string: "1150.00"),
        confidence: .high
    ),
    AmountSample(
        lines: [SampleLine(text: "TOTAL LKR 499.50", y: 0.2)],
        expected: Decimal(string: "499.50"),
        confidence: .high
    ),
    AmountSample(
        lines: [SampleLine(text: "Net Amount 2,400.00", y: 0.2)],
        expected: Decimal(string: "2400.00"),
        confidence: .high
    ),
    AmountSample(
        lines: [SampleLine(text: "Amount: LKR 75.00", y: 0.2)],
        expected: Decimal(string: "75.00"),
        confidence: .high
    ),
    AmountSample(
        lines: [SampleLine(text: "Amount Due: Rs. 350.00", y: 0.2)],
        expected: Decimal(string: "350.00"),
        confidence: .high
    ),
    AmountSample(
        lines: [
            SampleLine(text: "Total Qty 2", y: 0.5),
            SampleLine(text: "Grand Total Rs 1,150.00", y: 0.2)
        ],
        expected: Decimal(string: "1150.00"),
        confidence: .high
    ),
    AmountSample(
        lines: [SampleLine(text: "Net 2400", y: 0.2)],
        expected: Decimal(string: "2400"),
        confidence: .low
    ),
    AmountSample(
        lines: [SampleLine(text: "Rs. 1,299.00", y: 0.2)],
        expected: Decimal(string: "1299.00"),
        confidence: .low
    ),
    AmountSample(
        lines: [SampleLine(text: "TOTAL 2", y: 0.2)],
        expected: nil,
        confidence: .missing
    ),
    AmountSample(
        lines: [
            SampleLine(text: "Total 500.00", y: 0.4),
            SampleLine(text: "Total 640.00", y: 0.2)
        ],
        expected: Decimal(string: "640.00"),
        confidence: .low
    )
]

/// Recognizer double that returns prepared lines and ignores the image.
private struct FixedTextRecognizer: TextRecognizing {
    var lines: [RecognizedLine]

    /// Returns the canned lines instead of scanning an image.
    func recognizeText(in image: UIImage) async throws -> [RecognizedLine] {
        lines
    }
}
