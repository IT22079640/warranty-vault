//
//  CategorySuggester.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Suggests an item category from receipt text using NaturalLanguage and keywords.
//

import Foundation
import NaturalLanguage

/// A category guess the add screen can show before the user confirms it.
struct CategorySuggestion: Equatable {
    /// Suggested product group. `.other` means no keyword was convincing.
    var category: ItemCategory
    /// `.low` and `.missing` should be highlighted in the form.
    var confidence: ParseConfidence
}

/// Matches receipt wording to `ItemCategory` with a keyword dictionary and NaturalLanguage.
struct CategorySuggester {
    private let keywords: [ItemCategory: [String]]
    private let embedding: NLEmbedding?

    /// Shared English embedding. Nil when the model is not installed on the device.
    private static let englishEmbedding = NLEmbedding.wordEmbedding(for: .english)

    /// Loads keywords from the app bundle and the English word embedding when it is installed.
    init(bundle: Bundle = CategoryKeywordCatalog.bundle) throws {
        try self.init(keywords: CategoryKeywordCatalog.load(from: bundle), embedding: Self.englishEmbedding)
    }

    /// Uses an already loaded dictionary. Pass `embedding` as nil to skip neighbour matching.
    init(keywords: [ItemCategory: [String]], embedding: NLEmbedding? = nil) {
        self.keywords = keywords.mapValues { values in
            values.map { $0.lowercased() }
        }
        self.embedding = embedding
    }

    /// Suggests a category from the full receipt text.
    func suggest(for receiptText: String) -> CategorySuggestion {
        let normalized = normalize(receiptText)
        guard !normalized.isEmpty else {
            return CategorySuggestion(category: .other, confidence: .missing)
        }
        let tokens = lemmas(in: receiptText)
        var scores: [ItemCategory: Int] = [:]
        var earliest: [ItemCategory: String.Index] = [:]
        for category in ItemCategory.allCases where category != .other {
            score(category, in: normalized, tokens: tokens, scores: &scores, earliest: &earliest)
        }
        applyEmbeddingBoost(tokens: tokens, scores: &scores)
        return suggestion(from: scores, earliest: earliest, in: normalized)
    }

    /// Suggests a category from recognized lines joined in reading order.
    func suggest(from lines: [RecognizedLine]) -> CategorySuggestion {
        let text = lines.map(\.text).joined(separator: " ")
        return suggest(for: text)
    }

    /// Adds keyword hits for one category.
    private func score(
        _ category: ItemCategory,
        in normalized: String,
        tokens: Set<String>,
        scores: inout [ItemCategory: Int],
        earliest: inout [ItemCategory: String.Index]
    ) {
        for keyword in keywords[category] ?? [] {
            let needle = keyword.lowercased()
            guard !needle.isEmpty else {
                continue
            }
            if let found = normalized.range(of: needle) {
                scores[category, default: 0] += max(1, needle.split(separator: " ").count)
                recordEarliest(found.lowerBound, for: category, earliest: &earliest)
            } else if tokens.contains(needle) {
                scores[category, default: 0] += 1
            }
        }
    }

    /// Keeps the earliest place a category was mentioned, for tie breaks.
    private func recordEarliest(
        _ index: String.Index,
        for category: ItemCategory,
        earliest: inout [ItemCategory: String.Index]
    ) {
        guard let previous = earliest[category] else {
            earliest[category] = index
            return
        }
        if index < previous {
            earliest[category] = index
        }
    }

    /// When no keyword matched, borrows a close English neighbour from the embedding.
    private func applyEmbeddingBoost(tokens: Set<String>, scores: inout [ItemCategory: Int]) {
        guard scores.values.allSatisfy({ $0 == 0 }), let embedding else {
            return
        }
        for token in tokens where embedding.contains(token) {
            boost(token, using: embedding, scores: &scores)
        }
    }

    /// Gives one point to a category whose keyword sits close to `token` in the embedding.
    private func boost(_ token: String, using embedding: NLEmbedding, scores: inout [ItemCategory: Int]) {
        for category in ItemCategory.allCases where category != .other {
            let neighbours = (keywords[category] ?? []).filter { embedding.contains($0) && !$0.contains(" ") }
            let closest = neighbours.compactMap { embedding.distance(between: token, and: $0) }.min()
            if let closest, closest <= 0.75 {
                scores[category, default: 0] += 1
            }
        }
    }

    /// Turns scores into one suggestion. A tie stays low confidence so the UI can flag it.
    private func suggestion(
        from scores: [ItemCategory: Int],
        earliest: [ItemCategory: String.Index],
        in normalized: String
    ) -> CategorySuggestion {
        let ranked = scores.sorted { lhs, rhs in
            if lhs.value != rhs.value {
                return lhs.value > rhs.value
            }
            let left = earliest[lhs.key] ?? normalized.endIndex
            let right = earliest[rhs.key] ?? normalized.endIndex
            return left < right
        }
        guard let best = ranked.first, best.value > 0 else {
            return CategorySuggestion(category: .other, confidence: .low)
        }
        let second = ranked.dropFirst().first?.value ?? 0
        let confidence: ParseConfidence = best.value > second ? .high : .low
        return CategorySuggestion(category: best.key, confidence: confidence)
    }

    /// Lowercases receipt text and collapses whitespace for phrase checks.
    private func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let parts = folded.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        return parts.joined(separator: " ")
    }

    /// Lemmatizes words so plurals can match a singular keyword.
    private func lemmas(in text: String) -> Set<String> {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        if let language = recognizer.dominantLanguage {
            tagger.setLanguage(language, range: text.startIndex..<text.endIndex)
        }
        var words: Set<String> = []
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lemma,
            options: [.omitPunctuation, .omitWhitespace]
        ) { tag, range in
            words.insert(String(text[range]).lowercased())
            if let lemma = tag?.rawValue.lowercased(), !lemma.isEmpty {
                words.insert(lemma)
            }
            return true
        }
        return words
    }
}
