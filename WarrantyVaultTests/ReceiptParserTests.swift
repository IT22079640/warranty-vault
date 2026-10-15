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
    private let parser = ReceiptParser(
        timeZone: TimeZone(secondsFromGMT: 0) ?? .gmt,
        referenceDate: receiptReferenceDate
    )

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
            line("01/03/2026", y: 0.4)
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
            line("Valid until 01/06/2026", y: 0.4)
        ])
        let parts = dayParts(parsed.purchaseDate.value)

        #expect(parts.year == 2026)
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

    /// Totals stay on the amount paid when cash, change, tax, or a discount is also printed.
    @Test(arguments: totalAmountReceipts)
    func parsesPaidTotalNotChange(sample: TotalAmountReceipt) {
        let parsed = parser.parse(sample.lines.enumerated().map { index, text in
            line(text, y: CGFloat(sample.lines.count - index))
        })

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

    /// Noisy receipt lines, including several dates and dates glued to a time.
    @Test(arguments: noisyDateReceipts)
    func parsesNoisyReceiptDates(sample: NoisyDateReceipt) {
        let parsed = parser.parse(sample.lines.enumerated().map { index, text in
            line(text, y: CGFloat(sample.lines.count - index))
        })
        let parts = dayParts(parsed.purchaseDate.value)

        #expect(parts.year == sample.year)
        #expect(parts.month == sample.month)
        #expect(parts.day == sample.day)
        #expect(parsed.purchaseDate.confidence == sample.confidence)
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

/// 15 October 2026, the day the noisy receipt samples are judged against.
private let receiptReferenceDate: Date = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar.date(from: DateComponents(year: 2026, month: 10, day: 15))
        ?? Date(timeIntervalSince1970: 0)
}()

/// One noisy receipt and the purchase date it should produce.
struct NoisyDateReceipt: Sendable {
    var name: String
    var lines: [String]
    var year: Int?
    var month: Int?
    var day: Int?
    var confidence: ParseConfidence
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

/// Receipt snippets with OCR noise, several dates, and times glued to the date.
private let noisyDateReceipts: [NoisyDateReceipt] = [
    NoisyDateReceipt(name: "slash with 24-hour time", lines: ["Abans", "Date: 12/10/2026 14:33", "Grand Total Rs 4500.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "two-digit year with PM", lines: ["Softlogic", "Dt 12/10/26 02:33 PM", "TOTAL LKR 1299.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "dashed bill date", lines: ["Singer", "Bill date 12-10-2026", "Net Amount 2400.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "dotted date", lines: ["Cargills", "Date 12.10.2026", "Total Rs 890.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "iso date", lines: ["Keells", "Invoice date 2026-10-12", "Grand Total 1500.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "iso slashes", lines: ["Dialog", "Txn date 2026/10/12", "Amount Due Rs 3200.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "day month abbreviation", lines: ["Abans", "Purchased 12 Oct 2026", "Total Rs 999.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "day full month", lines: ["Softlogic", "Date 12 October 2026", "Grand Total Rs 2100.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "month first", lines: ["Singer", "Date: Oct 12, 2026", "TOTAL 640.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "spaces inside the date", lines: ["Abans", "Date: 12 / 10 / 2026", "Grand Total Rs 100.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "date glued to its label", lines: ["Abans", "Date:12/10/2026", "Total Rs 100.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "O read as zero", lines: ["Abans", "Date: 12/1O/2O26", "Total Rs 100.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "l and I read as one", lines: ["Abans", "Date: l2/I0/2026", "Total Rs 100.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "S read as five", lines: ["Abans", "Date: 1S/10/2026", "Total Rs 100.00"], year: 2026, month: 10, day: 15, confidence: .high),
    NoisyDateReceipt(name: "time glued to a four-digit year", lines: ["Abans", "Date:12/10/202614:33", "Total Rs 100.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "time glued to a two-digit year", lines: ["Abans", "Dt:12/10/2614:33", "Total Rs 100.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "invoice beats a future warranty", lines: ["Abans", "12/09/2026", "Warranty until 12/10/2028", "Invoice date 12/10/2026"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "printed date kept when cover dates are future", lines: ["Abans", "Printed date 01/09/2026", "Expiry date 01/09/2027", "Warranty until 01/01/2028"], year: 2026, month: 9, day: 1, confidence: .high),
    NoisyDateReceipt(name: "two unlabeled dates stay uncertain", lines: ["Abans", "05/08/2026", "01/03/2026", "Total Rs 10.00"], year: 2026, month: 8, day: 5, confidence: .low),
    NoisyDateReceipt(name: "bill date beats an earlier warranty", lines: ["Abans", "Warranty until 01/03/2026", "Bill date 12/10/2026"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "date older than 15 years", lines: ["Abans", "Date: 12/10/2005", "Total Rs 10.00"], year: nil, month: nil, day: nil, confidence: .missing),
    NoisyDateReceipt(name: "future date", lines: ["Abans", "Date: 12/10/2027", "Total Rs 10.00"], year: nil, month: nil, day: nil, confidence: .missing),
    NoisyDateReceipt(name: "impossible day", lines: ["Abans", "Date: 32/10/2026", "Total Rs 10.00"], year: nil, month: nil, day: nil, confidence: .missing),
    NoisyDateReceipt(name: "dotted two-digit year", lines: ["Abans", "Date 12.10.26", "Total Rs 10.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "dashed two-digit year", lines: ["Abans", "Txn date 12-10-26", "Total Rs 10.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "keyword on the previous line", lines: ["Abans", "Invoice date", "12/10/2026", "Total Rs 10.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "spaces and confused letters", lines: ["Abans", "Date : l2 / lO / 2O26", "Total Rs 10.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "month name with confused digits", lines: ["Abans", "Date: l2 0ctober 2O26", "Total Rs 10.00"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "two date labels stay uncertain", lines: ["Abans", "Date 01/02/2026", "Date 12/10/2026"], year: 2026, month: 2, day: 1, confidence: .low),
    NoisyDateReceipt(name: "purchased month name beats a future warranty", lines: ["Abans", "Purchased on 7 November 2025", "Warranty until 07/11/2027", "Cashier 14:33"], year: 2025, month: 11, day: 7, confidence: .high),
    NoisyDateReceipt(name: "exactly 15 years old", lines: ["Abans", "Date: 15/10/2011"], year: 2011, month: 10, day: 15, confidence: .high),
    NoisyDateReceipt(name: "one day older than 15 years", lines: ["Abans", "Date: 14/10/2011"], year: nil, month: nil, day: nil, confidence: .missing),
    NoisyDateReceipt(name: "invoice and warranty on one line", lines: ["Abans", "Invoice date 12/10/2026 Warranty until 01/06/2028"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "month-first OCR zero", lines: ["Abans", "Date: 0ct 12, 2026"], year: 2026, month: 10, day: 12, confidence: .high),
    NoisyDateReceipt(name: "morning time", lines: ["Abans", "Date 5/1/2026 09:15 AM"], year: 2026, month: 1, day: 5, confidence: .high)
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

/// One receipt and the amount that should be saved as the price paid.
struct TotalAmountReceipt: Sendable {
    var name: String
    var lines: [String]
    var expected: Decimal?
    var confidence: ParseConfidence
}

/// Receipts where cash, change, tax, or OCR noise used to hide the real total.
private let totalAmountReceipts: [TotalAmountReceipt] = [
    TotalAmountReceipt(
        name: "change on the following lines",
        lines: ["TOTAL:", "Rs. 129,900.00", "CASH:", "Rs. 130,000.00", "CHANGE:", "Rs. 100.00"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "change on the next line",
        lines: ["TOTAL Rs. 129,900.00", "CHANGE", "Rs. 100.00"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "cash larger than the total",
        lines: ["TOTAL: Rs. 129,900.00", "CASH: Rs. 130,000.00", "CHANGE: Rs. 100.00"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "subtotal loses to grand total",
        lines: ["Sub total 100,000.00", "Grand Total Rs. 129,900.00"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "vat is not the total",
        lines: ["VAT Rs. 15,588.00", "TOTAL Rs. 129,900.00"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "tax is not the total",
        lines: ["Tax 8,000.00", "Total payable Rs. 129,900.00"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "discount is not the total",
        lines: ["Discount Rs. 5,000.00", "Net total Rs. 129,900.00"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "total discount is not the total",
        lines: ["Total discount 5,000.00", "TOTAL 129,900.00"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "total savings is not the total",
        lines: ["Total savings Rs. 2,000.00", "Amount payable LKR 129,900.00"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "total items is not the total",
        lines: ["Total items 3", "TOTAL Rs. 129,900.00"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "currency glued to the amount",
        lines: ["TOTAL: Rs.129,900.00"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "rupees without decimals",
        lines: ["TOTAL Rs 129900"],
        expected: Decimal(string: "129900"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "lkr with grouping",
        lines: ["TOTAL LKR 129,900.00"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "trailing slash for no cents",
        lines: ["TOTAL 129,900/-"],
        expected: Decimal(string: "129900"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "ocr digits in the amount",
        lines: ["TOTAL Rs. l29,9OO.OO"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "european separators",
        lines: ["TOTAL 129.900,00"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "two totals stay uncertain",
        lines: ["Total Rs. 100,000.00", "Grand Total Rs. 129,900.00"],
        expected: Decimal(string: "129900.00"),
        confidence: .low
    ),
    TotalAmountReceipt(
        name: "tendered minus change confirms the total",
        lines: ["Amount due Rs. 129,900.00", "Tendered Rs. 130,000.00", "Change Rs. 100.00"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "card and payment lines are ignored",
        lines: ["Card Rs. 50,000.00", "Payment Rs. 79,900.00", "TOTAL Rs. 129,900.00"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "round off and balance are ignored",
        lines: ["Round off Rs. 0.50", "Balance Rs. 0.00", "TOTAL Rs. 129,900.00"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "label without a colon",
        lines: ["TOTAL", "129,900.00", "CASH", "130,000.00", "CHANGE", "100.00"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "change alone is not a total",
        lines: ["CHANGE:", "Rs. 100.00"],
        expected: nil,
        confidence: .missing
    ),
    TotalAmountReceipt(
        name: "dotted thousands from ocr",
        lines: ["TOTAL 129.900.00"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
    ),
    TotalAmountReceipt(
        name: "received and paid are ignored",
        lines: ["Received Rs. 130,000.00", "Paid Rs. 130,000.00", "Amount due 129,900.00"],
        expected: Decimal(string: "129900.00"),
        confidence: .high
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
