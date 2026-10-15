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
    private let referenceDate: Date
    private let numberPattern = /(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d{1,2}))?/
    private static let currencyPrefix = try? NSRegularExpression(
        pattern: #"(?i)(?:^|[^A-Za-z])(rs\.?|lkr|රු)\s*$"#
    )

    /// Creates a parser. Dates are built in `timeZone` so tests can pin midnight.
    ///
    /// `referenceDate` is "today" for the purchase window: later dates, and dates more than 15 years earlier, are ignored.
    init(timeZone: TimeZone = .current, referenceDate: Date = .now) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.referenceDate = referenceDate
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
            let previous = index > 0 ? lines[index - 1].text : nil
            for (position, hit) in dateHits(on: line.text, previousLine: previous).enumerated() {
                guard isPlausiblePurchase(hit.date) else {
                    continue
                }
                hits.append(DateHit(date: hit.date, score: hit.score, index: index, position: position))
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

    /// Prefers a labeled purchase date, then a line closer to the top, then the earlier date on that line.
    private func prefersEarlierDate(_ lhs: DateHit, _ rhs: DateHit) -> Bool {
        if lhs.score == rhs.score {
            if lhs.index == rhs.index {
                return lhs.position > rhs.position
            }
            return lhs.index > rhs.index
        }
        return lhs.score < rhs.score
    }

    /// True when `date` is not in the future and is not more than 15 years before the reference day.
    private func isPlausiblePurchase(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: referenceDate)
        guard day <= today else {
            return false
        }
        guard let oldest = calendar.date(byAdding: .year, value: -15, to: today) else {
            return false
        }
        return day >= calendar.startOfDay(for: oldest)
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

    /// Scores the words in front of one date. Expiry loses to a purchase label, then to "date" or "dt".
    private func keywordScore(for text: String) -> Int {
        let lower = text.lowercased()
        if lower.range(of: expiryWording, options: .regularExpression) != nil {
            return 10
        }
        if lower.range(of: purchaseWording, options: .regularExpression) != nil {
            return 100
        }
        if lower.range(of: dateKeyword, options: .regularExpression) != nil {
            return 80
        }
        return 40
    }

    /// Dates on `text`, each scored from the label in front of it.
    ///
    /// A date on its own line inherits a keyword from the previous line when that line has no date.
    private func dateHits(on text: String, previousLine: String?) -> [(date: Date, score: Int)] {
        let normalized = normalizeDateTokens(in: text)
        let found = locatedDates(in: normalized)
        let previousDates = previousLine.map { extractDates(from: $0) } ?? []
        return found.enumerated().map { position, raw in
            let prefixStart = position == 0 ? normalized.startIndex : found[position - 1].range.upperBound
            var score = keywordScore(for: String(normalized[prefixStart..<raw.range.lowerBound]))
            if position == 0, score == 40, previousDates.isEmpty, let previousLine {
                let inherited = keywordScore(for: previousLine)
                if inherited > score {
                    score = inherited
                }
            }
            return (raw.date, score)
        }
    }

    /// Finds supported dates in `text`. Numeric dates are day-first, not month-first.
    private func extractDates(from text: String) -> [Date] {
        locatedDates(in: normalizeDateTokens(in: text)).map(\.date)
    }

    /// Locates every supported date. Longer numeric forms are kept when a shorter one overlaps them.
    private func locatedDates(in normalized: String) -> [LocatedDate] {
        var accepted: [LocatedDate] = []
        let fullRange = NSRange(normalized.startIndex..., in: normalized)
        for (expression, layout) in dateExpressions {
            for match in expression.matches(in: normalized, range: fullRange) {
                guard let range = Range(match.range, in: normalized),
                      !accepted.contains(where: { $0.range.overlaps(range) }),
                      let date = date(from: match, layout: layout, in: normalized) else {
                    continue
                }
                accepted.append(LocatedDate(date: date, range: range))
            }
        }
        return accepted.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// Builds a date from one regular-expression match. Nil when the day or month cannot exist.
    private func date(from match: NSTextCheckingResult, layout: DateLayout, in text: String) -> Date? {
        let parts = (1..<match.numberOfRanges).compactMap { group(match, $0, in: text) }
        guard parts.count >= 3 else {
            return nil
        }
        switch layout {
        case .yearMonthDay:
            return makeDate(day: parts[2], month: parts[1], year: parts[0])
        case .dayMonthYear:
            return makeDate(day: parts[0], month: parts[1], year: parts[2])
        case .dayMonthYearShort:
            guard let shortYear = Int(parts[2]) else {
                return nil
            }
            return makeDate(day: parts[0], month: parts[1], year: String(2000 + shortYear))
        case .dayNameYear:
            guard let month = monthNumber(from: parts[1]) else {
                return nil
            }
            return makeDate(day: parts[0], month: month, year: parts[2])
        case .nameDayYear:
            guard let month = monthNumber(from: parts[0]) else {
                return nil
            }
            return makeDate(day: parts[1], month: month, year: parts[2])
        }
    }

    /// Rewrites OCR noise inside date-shaped spans. Words outside those spans stay as read.
    private func normalizeDateTokens(in text: String) -> String {
        let numeric = replacingLooseNumericDates(in: text)
        return replacingLooseMonthDates(in: numeric)
    }

    /// Turns "l2 / lO / 2O26" into "12/10/2026" without changing the rest of the line.
    private func replacingLooseNumericDates(in text: String) -> String {
        replacingMatches(in: text, expression: looseNumericDate) { match, source in
            guard let first = group(match, 1, in: source),
                  let separator = group(match, 2, in: source),
                  let second = group(match, 3, in: source),
                  let third = group(match, 4, in: source) else {
                return nil
            }
            let cleaned = [digitToken(first), digitToken(second), digitToken(third)]
            guard cleaned.allSatisfy({ $0.allSatisfy(\.isNumber) }) else {
                return nil
            }
            return "\(cleaned[0])\(separator)\(cleaned[1])\(separator)\(cleaned[2])"
        }
    }

    /// Fixes digits inside "l2 0ctober 2O26" and "0ct 12, 2026" when the word is a month.
    private func replacingLooseMonthDates(in text: String) -> String {
        let dayFirst = replacingMatches(in: text, expression: looseDayMonth) { match, source in
            guard let day = group(match, 1, in: source),
                  let month = group(match, 2, in: source),
                  let year = group(match, 3, in: source),
                  monthNumber(from: monthToken(month)) != nil else {
                return nil
            }
            return "\(digitToken(day)) \(monthToken(month)) \(digitToken(year))"
        }
        return replacingMatches(in: dayFirst, expression: looseMonthFirst) { match, source in
            guard let month = group(match, 1, in: source),
                  let day = group(match, 2, in: source),
                  let year = group(match, 3, in: source),
                  monthNumber(from: monthToken(month)) != nil else {
                return nil
            }
            return "\(monthToken(month)) \(digitToken(day)), \(digitToken(year))"
        }
    }

    /// Replaces matches from the end so earlier ranges stay aligned. Nil replacements are left alone.
    private func replacingMatches(
        in text: String,
        expression: NSRegularExpression?,
        transform: (NSTextCheckingResult, String) -> String?
    ) -> String {
        guard let expression else {
            return text
        }
        let matches = expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var result = text
        for match in matches.reversed() {
            guard let replacement = transform(match, text),
                  let range = Range(match.range, in: result) else {
                continue
            }
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }

    /// The text of one capture group, or nil when that group did not participate.
    private func group(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else {
            return nil
        }
        return String(text[swiftRange])
    }

    /// Maps O, l, I, and S to the digits Vision confuses them with.
    private func digitToken(_ token: String) -> String {
        var result = ""
        for character in token {
            switch character {
            case "O", "o":
                result.append("0")
            case "l", "I", "|":
                result.append("1")
            case "S", "s":
                result.append("5")
            default:
                result.append(character)
            }
        }
        return result
    }

    /// Maps digits that Vision drops into a month name back to letters.
    private func monthToken(_ token: String) -> String {
        var result = ""
        for character in token {
            switch character {
            case "0":
                result.append("o")
            case "1":
                result.append("l")
            case "5":
                result.append("s")
            default:
                result.append(character)
            }
        }
        return result
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

    /// Picks the paid total, ignoring cash, change, tax, and discount lines.
    ///
    /// A label with no amount applies to the next line. Cash minus change confirms a matching total.
    private func totalAmount(in lines: [RecognizedLine]) -> ParsedField<Decimal> {
        var candidates: [AmountCandidate] = []
        var cash: [Decimal] = []
        var change: [Decimal] = []
        var carried: AmountRole = .plain
        for line in lines {
            let role = amountRole(for: line.text)
            let hits = amountHits(in: line.text)
            if hits.isEmpty {
                carried = role == .plain ? .plain : role
                continue
            }
            let applied = role == .plain ? carried : role
            carried = .plain
            for hit in hits {
                switch applied {
                case .total(let score):
                    candidates.append(
                        AmountCandidate(
                            amount: hit.amount,
                            score: score,
                            hasCurrency: hit.hasCurrency,
                            midY: line.boundingBox.midY,
                            confirmed: false
                        )
                    )
                case .cash:
                    cash.append(hit.amount)
                case .change:
                    change.append(hit.amount)
                case .reject, .plain:
                    guard applied == .plain, hit.hasCurrency else {
                        continue
                    }
                    candidates.append(
                        AmountCandidate(
                            amount: hit.amount,
                            score: 35,
                            hasCurrency: true,
                            midY: line.boundingBox.midY,
                            confirmed: false
                        )
                    )
                }
            }
        }
        for index in candidates.indices {
            candidates[index].confirmed = confirms(
                candidates[index].amount,
                cash: cash,
                change: change
            )
        }
        guard let best = candidates.max(by: prefersWeakerAmount) else {
            return ParsedField(value: nil, confidence: .missing)
        }
        let confidence = amountConfidence(best: best, candidates: candidates)
        return ParsedField(value: best.amount, confidence: confidence)
    }

    /// True when cash minus change equals `amount`.
    private func confirms(_ amount: Decimal, cash: [Decimal], change: [Decimal]) -> Bool {
        for paid in cash {
            for returned in change where paid - returned == amount {
                return true
            }
        }
        return false
    }

    /// How a line should be treated when its amount is chosen.
    private func amountRole(for text: String) -> AmountRole {
        let lower = text.lowercased()
        if lower.range(of: #"grand\s*total"#, options: .regularExpression) != nil {
            return .total(100)
        }
        if lower.range(of: #"net\s*total"#, options: .regularExpression) != nil {
            return .total(90)
        }
        if lower.range(of: #"total\s*payable"#, options: .regularExpression) != nil {
            return .total(88)
        }
        if lower.range(of: #"amount\s*due"#, options: .regularExpression) != nil {
            return .total(85)
        }
        if lower.range(of: #"amount\s*payable"#, options: .regularExpression) != nil {
            return .total(85)
        }
        if lower.range(of: #"net\s*amount"#, options: .regularExpression) != nil {
            return .total(90)
        }
        if lower.range(of: #"sub\s*total"#, options: .regularExpression) != nil {
            return .reject
        }
        if lower.range(of: #"total\s*savings?"#, options: .regularExpression) != nil {
            return .reject
        }
        if lower.range(of: #"total\s*items?"#, options: .regularExpression) != nil {
            return .reject
        }
        if lower.range(of: #"item\s*count"#, options: .regularExpression) != nil {
            return .reject
        }
        if lower.range(of: #"total\s*(qty|quantity|discount)"#, options: .regularExpression) != nil {
            return .reject
        }
        if lower.range(of: #"round\s*off"#, options: .regularExpression) != nil {
            return .reject
        }
        if lower.range(of: #"\bchange\b"#, options: .regularExpression) != nil {
            return .change
        }
        if lower.range(of: #"\b(cash|tendered)\b"#, options: .regularExpression) != nil {
            return .cash
        }
        if lower.range(of: #"\b(balance|paid|payment|card|received|discount|savings?|vat|tax|qty|quantity)\b"#, options: .regularExpression) != nil {
            return .reject
        }
        if lower.range(of: #"\btotal\b"#, options: .regularExpression) != nil {
            return .total(75)
        }
        if lower.range(of: #"\bamount\b"#, options: .regularExpression) != nil {
            return .total(55)
        }
        if lower.range(of: #"\bnet\b"#, options: .regularExpression) != nil {
            return .total(45)
        }
        return .plain
    }

    /// Higher score wins. A cash-minus-change match beats a weaker label. Equal scores prefer the lower line.
    private func prefersWeakerAmount(_ lhs: AmountCandidate, _ rhs: AmountCandidate) -> Bool {
        if lhs.confirmed != rhs.confirmed {
            return rhs.confirmed
        }
        if lhs.score == rhs.score {
            if lhs.midY == rhs.midY {
                return lhs.amount < rhs.amount
            }
            return lhs.midY > rhs.midY
        }
        return lhs.score < rhs.score
    }

    /// High for one clear total, or when cash minus change matches it. Two different totals stay uncertain.
    private func amountConfidence(best: AmountCandidate, candidates: [AmountCandidate]) -> ParseConfidence {
        if best.confirmed {
            return .high
        }
        let contested = candidates.contains { $0.amount != best.amount }
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

    /// Pulls prices out of one line after dates have been removed and OCR digits repaired.
    private func amountHits(in text: String) -> [AmountHit] {
        let prepared = standardizeAmountSeparators(in: normalizeAmountDigits(in: stripDates(from: text)))
        return prepared.matches(of: numberPattern).compactMap { match in
            guard let amount = decimal(whole: match.1, cents: match.2) else {
                return nil
            }
            let hasCurrency = currencyPrecedes(match.range, in: prepared)
            if shouldIgnore(amount, hasCurrency: hasCurrency, cents: match.2) {
                return nil
            }
            return AmountHit(amount: amount, hasCurrency: hasCurrency)
        }
    }

    /// Turns O, l, and I into digits inside a number, leaving words such as TOTAL alone.
    private func normalizeAmountDigits(in text: String) -> String {
        replacingMatches(in: text, expression: amountNoise) { match, source in
            guard let token = group(match, 0, in: source), token.contains(where: \.isNumber) else {
                return nil
            }
            return digitToken(token)
        }
    }

    /// Rewrites `129.900,00` and `129.900.00` into `129900.00` before the usual parser runs.
    private func standardizeAmountSeparators(in text: String) -> String {
        let commaDecimal = replacingMatches(in: text, expression: europeanAmount) { match, source in
            guard let whole = group(match, 1, in: source), let cents = group(match, 2, in: source) else {
                return nil
            }
            return whole.replacingOccurrences(of: ".", with: "") + "." + cents
        }
        return replacingMatches(in: commaDecimal, expression: dottedThousandsAmount) { match, source in
            guard let whole = group(match, 1, in: source), let cents = group(match, 2, in: source) else {
                return nil
            }
            return whole.replacingOccurrences(of: ".", with: "") + "." + cents
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
        let normalized = normalizeDateTokens(in: text)
        let spans = locatedDates(in: normalized).map { raw -> (start: Int, length: Int) in
            let start = normalized.distance(from: normalized.startIndex, to: raw.range.lowerBound)
            let length = normalized.distance(from: raw.range.lowerBound, to: raw.range.upperBound)
            return (start, length)
        }.sorted { $0.start > $1.start }
        var result = normalized
        for span in spans {
            let lower = result.index(result.startIndex, offsetBy: span.start)
            let upper = result.index(lower, offsetBy: span.length)
            result.replaceSubrange(lower..<upper, with: " ")
        }
        return result
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
    var position: Int
}

/// A date and the span it occupied after OCR cleanup.
private struct LocatedDate {
    var date: Date
    var range: Range<String.Index>
}

/// How the three captured pieces of a date are ordered.
private enum DateLayout {
    /// `yyyy-MM-dd` or `yyyy/MM/dd`.
    case yearMonthDay
    /// `dd/MM/yyyy`, `dd-MM-yyyy`, or `dd.MM.yyyy`.
    case dayMonthYear
    /// `dd/MM/yy` and the same day-first form with dashes or dots.
    case dayMonthYearShort
    /// `dd MMM yyyy` or `dd MMMM yyyy`.
    case dayNameYear
    /// `MMM dd, yyyy`.
    case nameDayYear
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
    var confirmed: Bool
}

/// Whether a line names a total, names money that must not be the total, or names nothing.
private enum AmountRole: Equatable {
    /// A total label and how strongly it should win.
    case total(Int)
    /// Cash or tendered, used only to check the total.
    case cash
    /// Change, used only to check the total.
    case change
    /// Tax, discount, quantity, or another line that is not the amount paid.
    case reject
    /// No money label.
    case plain
}

/// Headings that sit above the shop name.
private let headerNoise = #"^(tax\s+)?invoice\b|^receipt\b|^cash\s+(memo|sale)\b|^sales\s+receipt\b|^welcome\b|^thank\s+you\b|^original\b|^duplicate\b|^customer\s+copy\b|^vat\b|^tin\b|^tel\b|^phone\b|^hotline\b"#

/// Address fragments that are not the merchant name.
private let addressNoise = #"\b(road|street|lane|avenue|colombo|kandy|galle|sri lanka)\b|^(no\.?)\b"#

/// Words that mean the date is cover ending, not the day of purchase.
private let expiryWording = #"warrant|expir|valid until|due date"#

/// Words that mean the date is the day of purchase.
private let purchaseWording = #"invoice\s*date|purchase\s*date|bill\s*date|txn\s*date|transaction\s*date|\bpurchased\b"#

/// A generic date label. Checked after purchase and expiry so "expiry date" stays an expiry.
private let dateKeyword = #"\b(?:date|dt)\b"#

/// A time glued to a two-digit year, or any non-digit, so `26` is not the start of `2026`.
private let shortYearTail = #"(?=\d{1,2}[:.]\d{2}|\D|$)"#

/// Date shapes, longest numeric form first so a four-digit year is not read as two digits.
private let dateExpressions: [(NSRegularExpression, DateLayout)] = {
    let pairs: [(String, DateLayout)] = [
        (#"(\d{4})-(\d{2})-(\d{2})"#, .yearMonthDay),
        (#"(\d{4})/(\d{2})/(\d{2})"#, .yearMonthDay),
        (#"(\d{1,2})\.(\d{1,2})\.(\d{4})"#, .dayMonthYear),
        (#"(\d{1,2})\.(\d{1,2})\.(\d{2})"# + shortYearTail, .dayMonthYearShort),
        (#"(\d{1,2})-(\d{1,2})-(\d{4})"#, .dayMonthYear),
        (#"(\d{1,2})-(\d{1,2})-(\d{2})"# + shortYearTail, .dayMonthYearShort),
        (#"(\d{1,2})/(\d{1,2})/(\d{4})"#, .dayMonthYear),
        (#"(\d{1,2})/(\d{1,2})/(\d{2})"# + shortYearTail, .dayMonthYearShort),
        (#"(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{4})"#, .dayNameYear),
        (#"([A-Za-z]{3,9})\s+(\d{1,2}),?\s*(\d{4})"#, .nameDayYear)
    ]
    return pairs.compactMap { pattern, layout in
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        return (expression, layout)
    }
}()

/// Numeric dates with spaces and the letters Vision confuses with digits.
private let looseNumericDate = try? NSRegularExpression(
    pattern: #"([0-9OoIl|Ss]{1,4})\s*([/\-.])\s*([0-9OoIl|Ss]{1,2})\s*\2\s*([0-9OoIl|Ss]{2,4})"#
)

/// `dd MMM yyyy` with the same digit/letter mix inside the day, month, and year.
private let looseDayMonth = try? NSRegularExpression(
    pattern: #"([0-9OoIl|]{1,2})\s+([A-Za-z0-9]{3,9})\s+([0-9OoIl|Ss]{4})"#
)

/// `MMM dd, yyyy` with the same digit/letter mix.
private let looseMonthFirst = try? NSRegularExpression(
    pattern: #"([A-Za-z0-9]{3,9})\s+([0-9OoIl|]{1,2}),?\s*([0-9OoIl|Ss]{4})"#
)

/// A run of digits, separators, and letters Vision confuses with digits.
private let amountNoise = try? NSRegularExpression(pattern: #"[0-9OoIl|.,]{2,}"#)

/// Thousands written with dots and cents written with a comma, as in `129.900,00`.
private let europeanAmount = try? NSRegularExpression(pattern: #"(\d{1,3}(?:\.\d{3})+),(\d{2})"#)

/// Thousands and cents both written with dots, as in `129.900.00`.
private let dottedThousandsAmount = try? NSRegularExpression(pattern: #"(\d{1,3}(?:\.\d{3})+)\.(\d{2})(?!\d)"#)

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
