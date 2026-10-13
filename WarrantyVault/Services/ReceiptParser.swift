//
//  ReceiptParser.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Turns recognized receipt lines into a store, a purchase date, and a total.
//

import Foundation

/// Extracts store, purchase date, and total from receipt lines.
struct ReceiptParser {
    private let calendar: Calendar
    private let numberPattern = /(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d{1,2}))?/
    private static let currencyPrefix = try? NSRegularExpression(
        pattern: #"(?i)(?:^|[^A-Za-z])(rs\.?|lkr|රු)\s*$"#
    )
    private let isoDatePattern = /(\d{4})-(\d{2})-(\d{2})/
    private let dashedDatePattern = /(\d{1,2})-(\d{1,2})-(\d{4})/
    private let slashDatePattern = /(\d{1,2})\/(\d{1,2})\/(\d{4})/
    private let monthNameDatePattern = /(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{4})/

    /// Creates a parser. Dates are built in `timeZone` so tests can pin midnight.
    init(timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    /// Reads a receipt from lines that already include position and confidence.
    func parse(_ lines: [RecognizedLine]) -> ParsedReceipt {
        let ordered = topToBottom(lines)
        return ParsedReceipt(
            storeName: storeName(in: ordered),
            purchaseDate: purchaseDate(in: ordered),
            totalAmount: totalAmount(in: ordered)
        )
    }

    /// Puts the top of the receipt first. Vision's origin is the bottom left.
    private func topToBottom(_ lines: [RecognizedLine]) -> [RecognizedLine] {
        let hasPosition = lines.contains { $0.boundingBox.height > 0 || $0.boundingBox.minY > 0 }
        guard hasPosition else {
            return lines
        }
        return lines.sorted { lhs, rhs in
            if lhs.boundingBox.midY == rhs.boundingBox.midY {
                return lhs.boundingBox.minX < rhs.boundingBox.minX
            }
            return lhs.boundingBox.midY > rhs.boundingBox.midY
        }
    }

    /// Picks the merchant from the first real line at the top of the receipt.
    private func storeName(in lines: [RecognizedLine]) -> ParsedField<String> {
        let topLines = Array(lines.prefix(8))
        for (index, line) in topLines.enumerated() {
            guard isStoreCandidate(line.text) else {
                continue
            }
            let confidence: ParseConfidence = (line.confidence >= 0.75 && index <= 3) ? .high : .low
            return ParsedField(value: line.text, confidence: confidence)
        }
        return ParsedField(value: nil, confidence: .missing)
    }

    /// Rejects headings, dates, totals, addresses, and phone numbers.
    private func isStoreCandidate(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            return false
        }
        let lower = trimmed.lowercased()
        if lower.range(of: headerNoise, options: .regularExpression) != nil {
            return false
        }
        if lower.range(of: addressNoise, options: .regularExpression) != nil {
            return false
        }
        if lower.range(of: #"\d{7,}"#, options: .regularExpression) != nil {
            return false
        }
        if !extractDates(from: trimmed).isEmpty && letterCount(in: trimmed) < 4 {
            return false
        }
        if amountScore(for: lower) > 0 {
            return false
        }
        return letterCount(in: trimmed) >= 2
    }

    /// Counts letters so a line of digits is not treated as a shop name.
    private func letterCount(in text: String) -> Int {
        text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
    }

    /// Chooses the purchase date and marks expiry-only or competing dates as uncertain.
    private func purchaseDate(in lines: [RecognizedLine]) -> ParsedField<Date> {
        var hits: [DateHit] = []
        for (index, line) in lines.enumerated() {
            let score = dateScore(for: line.text)
            for date in extractDates(from: line.text) {
                hits.append(DateHit(date: date, score: score, index: index))
            }
        }
        guard let best = hits.max(by: prefersEarlierDate) else {
            return ParsedField(value: nil, confidence: .missing)
        }
        let rivals = hits.filter { !calendar.isDate($0.date, inSameDayAs: best.date) }
        let bestRival = rivals.max(by: prefersEarlierDate)
        let confidence = dateConfidence(best: best, bestRival: bestRival, hitCount: hits.count)
        return ParsedField(value: best.date, confidence: confidence)
    }

    /// Prefers a labeled purchase date, then a line closer to the top of the receipt.
    private func prefersEarlierDate(_ lhs: DateHit, _ rhs: DateHit) -> Bool {
        if lhs.score == rhs.score {
            return lhs.index > rhs.index
        }
        return lhs.score < rhs.score
    }

    /// High when the winning date is clearly the purchase date.
    private func dateConfidence(best: DateHit, bestRival: DateHit?, hitCount: Int) -> ParseConfidence {
        guard let bestRival else {
            return best.score >= 40 ? .high : .low
        }
        if best.score >= 80 && best.score > bestRival.score {
            return .high
        }
        if hitCount == 1 {
            return best.score >= 40 ? .high : .low
        }
        return .low
    }

    /// Scores a line by how likely its date is the purchase date rather than an expiry.
    private func dateScore(for text: String) -> Int {
        let lower = text.lowercased()
        if lower.range(of: expiryWording, options: .regularExpression) != nil {
            return 10
        }
        if lower.range(of: purchaseWording, options: .regularExpression) != nil {
            return 100
        }
        if lower.range(of: #"\bdate\b"#, options: .regularExpression) != nil {
            return 80
        }
        return 40
    }

    /// Finds supported dates in `text`. Numeric dates are day-first, not month-first.
    private func extractDates(from text: String) -> [Date] {
        var remaining = text
        var dates = isoDates(in: remaining)
        remaining = remaining.replacing(isoDatePattern, with: " ")
        dates.append(contentsOf: dashedDates(in: remaining))
        remaining = remaining.replacing(dashedDatePattern, with: " ")
        dates.append(contentsOf: slashDates(in: remaining))
        dates.append(contentsOf: monthNameDates(in: text))
        return dates
    }

    /// Reads `yyyy-MM-dd` dates before day-first dashes, so the year is not split.
    private func isoDates(in text: String) -> [Date] {
        text.matches(of: isoDatePattern).compactMap { match in
            guard let month = Int(match.2) else {
                return nil
            }
            return makeDate(day: match.3, month: month, year: match.1)
        }
    }

    /// Reads `dd-MM-yyyy` dates.
    private func dashedDates(in text: String) -> [Date] {
        text.matches(of: dashedDatePattern).compactMap { match in
            guard let month = Int(match.2) else {
                return nil
            }
            return makeDate(day: match.1, month: month, year: match.3)
        }
    }

    /// Reads `dd/MM/yyyy` dates.
    private func slashDates(in text: String) -> [Date] {
        text.matches(of: slashDatePattern).compactMap { match in
            guard let month = Int(match.2) else {
                return nil
            }
            return makeDate(day: match.1, month: month, year: match.3)
        }
    }

    /// Reads dates written as "13 Oct 2026" or "13 October 2026".
    private func monthNameDates(in text: String) -> [Date] {
        text.matches(of: monthNameDatePattern).compactMap { match in
            guard let month = monthNumber(from: String(match.2)) else {
                return nil
            }
            return makeDate(day: match.1, month: month, year: match.3)
        }
    }

    /// Builds a midnight date from numeric text and rejects impossible days such as 32 January.
    private func makeDate(day: some StringProtocol, month: some StringProtocol, year: some StringProtocol) -> Date? {
        guard let monthNumber = Int(month) else {
            return nil
        }
        return makeDate(day: day, month: monthNumber, year: year)
    }

    /// Builds a midnight date from a known month number and rejects impossible days such as 32 January.
    private func makeDate(day: some StringProtocol, month: Int, year: some StringProtocol) -> Date? {
        guard let dayNumber = Int(day), let yearNumber = Int(year) else {
            return nil
        }
        return makeDate(day: dayNumber, month: month, year: yearNumber)
    }

    /// Builds a midnight date and rejects impossible days such as 32 January.
    private func makeDate(day: Int, month: Int, year: Int) -> Date? {
        guard (1...12).contains(month), (1...31).contains(day), (1990...2100).contains(year) else {
            return nil
        }
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else {
            return nil
        }
        let checked = calendar.dateComponents([.year, .month, .day], from: date)
        guard checked.year == year, checked.month == month, checked.day == day else {
            return nil
        }
        return date
    }

    /// Maps an English month name or abbreviation to a month number.
    private func monthNumber(from name: String) -> Int? {
        let key = name.lowercased()
        if let month = monthNames[key] {
            return month
        }
        if key.hasPrefix("sept") {
            return 9
        }
        return monthNames[String(key.prefix(3))]
    }

    /// Picks the amount nearest a total keyword, preferring grand total over subtotal.
    private func totalAmount(in lines: [RecognizedLine]) -> ParsedField<Decimal> {
        var candidates: [AmountCandidate] = []
        for line in lines {
            let score = amountScore(for: line.text.lowercased())
            guard score > 0 else {
                continue
            }
            for hit in amountHits(in: line.text) {
                candidates.append(
                    AmountCandidate(
                        amount: hit.amount,
                        score: score,
                        hasCurrency: hit.hasCurrency,
                        midY: line.boundingBox.midY
                    )
                )
            }
        }
        guard let best = candidates.max(by: prefersWeakerAmount) else {
            return ParsedField(value: nil, confidence: .missing)
        }
        let confidence = amountConfidence(best: best, candidates: candidates)
        return ParsedField(value: best.amount, confidence: confidence)
    }

    /// Higher score wins. Equal scores prefer the line lower on the page.
    private func prefersWeakerAmount(_ lhs: AmountCandidate, _ rhs: AmountCandidate) -> Bool {
        if lhs.score == rhs.score {
            if lhs.midY == rhs.midY {
                return lhs.amount < rhs.amount
            }
            return lhs.midY > rhs.midY
        }
        return lhs.score < rhs.score
    }

    /// High when a total keyword is clearly stronger than the other numbers.
    private func amountConfidence(best: AmountCandidate, candidates: [AmountCandidate]) -> ParseConfidence {
        let contested = candidates.contains { rival in
            rival.amount != best.amount && abs(rival.score - best.score) <= 10
        }
        if contested {
            return .low
        }
        if best.score >= 75 {
            return .high
        }
        if best.score >= 55 && best.hasCurrency {
            return .high
        }
        return .low
    }

    /// Scores how strongly a line names the amount paid.
    private func amountScore(for lowercasedLine: String) -> Int {
        if lowercasedLine.range(of: #"grand\s*total"#, options: .regularExpression) != nil {
            return 100
        }
        if lowercasedLine.range(of: #"net\s*(amount|total)"#, options: .regularExpression) != nil {
            return 90
        }
        if lowercasedLine.range(of: #"amount\s*(due|payable)"#, options: .regularExpression) != nil {
            return 85
        }
        if lowercasedLine.range(of: #"sub\s*total"#, options: .regularExpression) != nil {
            return 20
        }
        if lowercasedLine.range(of: #"total\s*(qty|quantity|items|pcs)\b"#, options: .regularExpression) != nil {
            return lowercasedLine.range(of: #"\b(rs\.?|lkr|රු)\b"#, options: .regularExpression) == nil ? 0 : 40
        }
        if lowercasedLine.range(of: #"\btotal\b"#, options: .regularExpression) != nil {
            return 75
        }
        if lowercasedLine.range(of: #"\bamount\b"#, options: .regularExpression) != nil {
            return 55
        }
        if lowercasedLine.range(of: #"\bnet\b"#, options: .regularExpression) != nil {
            return 45
        }
        if lowercasedLine.range(of: #"\b(rs\.?|lkr|රු)\b"#, options: .regularExpression) != nil {
            return 35
        }
        return 0
    }

    /// Pulls prices out of one line after dates have been removed.
    private func amountHits(in text: String) -> [AmountHit] {
        let stripped = stripDates(from: text)
        return stripped.matches(of: numberPattern).compactMap { match in
            guard let amount = decimal(whole: match.1, cents: match.2) else {
                return nil
            }
            let hasCurrency = currencyPrecedes(match.range, in: stripped)
            if shouldIgnore(amount, hasCurrency: hasCurrency, cents: match.2) {
                return nil
            }
            return AmountHit(amount: amount, hasCurrency: hasCurrency)
        }
    }

    /// True when Rs, LKR, or රු sits immediately before a number.
    private func currencyPrecedes(_ range: Range<String.Index>, in text: String) -> Bool {
        guard let expression = Self.currencyPrefix else {
            return false
        }
        let prefix = String(text[..<range.lowerBound])
        let nsRange = NSRange(prefix.startIndex..<prefix.endIndex, in: prefix)
        return expression.firstMatch(in: prefix, options: [], range: nsRange) != nil
    }

    /// Drops tiny quantities and bare years that are not prices.
    private func shouldIgnore(_ amount: Decimal, hasCurrency: Bool, cents: Substring?) -> Bool {
        guard cents == nil, !hasCurrency, let whole = wholeNumber(amount) else {
            return false
        }
        if whole < 10 {
            return true
        }
        return (1990...2100).contains(whole)
    }

    /// Returns the integer when `amount` has no fractional part.
    private func wholeNumber(_ amount: Decimal) -> Int? {
        var source = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .down)
        guard rounded == amount, rounded >= 0, rounded <= Decimal(Int.max) else {
            return nil
        }
        return NSDecimalNumber(decimal: rounded).intValue
    }

    /// Removes date text so a year is not treated as a price.
    private func stripDates(from text: String) -> String {
        text.replacing(isoDatePattern, with: " ")
            .replacing(dashedDatePattern, with: " ")
            .replacing(slashDatePattern, with: " ")
            .replacing(monthNameDatePattern, with: " ")
    }

    /// Parses a matched number, keeping comma thousands separators out of the value.
    private func decimal(whole: Substring, cents: Substring?) -> Decimal? {
        let digits = whole.replacingOccurrences(of: ",", with: "")
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else {
            return nil
        }
        let composed: String
        if let cents {
            composed = "\(digits).\(cents)"
        } else {
            composed = digits
        }
        return Decimal(string: composed, locale: Locale(identifier: "en_US_POSIX"))
    }
}

/// A date found on one receipt line.
private struct DateHit {
    var date: Date
    var score: Int
    var index: Int
}

/// A price found on one receipt line.
private struct AmountHit {
    var amount: Decimal
    var hasCurrency: Bool
}

/// A scored price, including where on the page it was printed.
private struct AmountCandidate {
    var amount: Decimal
    var score: Int
    var hasCurrency: Bool
    var midY: CGFloat
}

/// Headings that sit above the shop name.
private let headerNoise = #"^(tax\s+)?invoice\b|^receipt\b|^cash\s+(memo|sale)\b|^sales\s+receipt\b|^welcome\b|^thank\s+you\b|^original\b|^duplicate\b|^customer\s+copy\b|^vat\b|^tin\b|^tel\b|^phone\b|^hotline\b"#

/// Address fragments that are not the merchant name.
private let addressNoise = #"\b(road|street|lane|avenue|colombo|kandy|galle|sri lanka)\b|^(no\.?)\b"#

/// Words that mean the date is cover ending, not the day of purchase.
private let expiryWording = #"warrant|expir|valid until|due date"#

/// Words that mean the date is the day of purchase.
private let purchaseWording = #"invoice date|purchase date|bill date|txn date|transaction date"#

/// English month names accepted on receipts.
private let monthNames: [String: Int] = [
    "jan": 1, "january": 1,
    "feb": 2, "february": 2,
    "mar": 3, "march": 3,
    "apr": 4, "april": 4,
    "may": 5,
    "jun": 6, "june": 6,
    "jul": 7, "july": 7,
    "aug": 8, "august": 8,
    "sep": 9, "sept": 9, "september": 9,
    "oct": 10, "october": 10,
    "nov": 11, "november": 11,
    "dec": 12, "december": 12
]
