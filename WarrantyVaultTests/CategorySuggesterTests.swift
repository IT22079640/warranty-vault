//
//  CategorySuggesterTests.swift
//  WarrantyVaultTests
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Checks keyword, plural, and tie-break category suggestions.
//

import Testing
@testable import WarrantyVault

struct CategorySuggesterTests {

    /// The bundled dictionary contains a list for every product group except other.
    @Test func keywordResourceLoadsKnownCategories() throws {
        let keywords = try CategoryKeywordCatalog.load()

        #expect(keywords[.phone]?.contains("iphone") == true)
        #expect(keywords[.laptop]?.contains("macbook") == true)
        #expect(keywords[.appliance]?.contains("washing machine") == true)
        #expect(keywords[.furniture]?.contains("sofa") == true)
        #expect(keywords[.vehicle]?.contains("engine oil") == true)
        #expect(keywords[.other] == nil)
    }

    /// Product phrases map onto the expected category.
    @Test(arguments: suggestionSamples)
    func suggestsCategoryFromReceiptText(sample: SuggestionSample) throws {
        let suggestion = try CategorySuggester().suggest(for: sample.text)

        #expect(suggestion.category == sample.category)
        #expect(suggestion.confidence == sample.confidence)
    }

    /// Joined receipt lines use the same dictionary as a single string.
    @Test func suggestsFromRecognizedLines() throws {
        let suggester = try CategorySuggester()
        let suggestion = suggester.suggest(from: [
            RecognizedLine(text: "Singer", confidence: 0.9, boundingBox: .zero),
            RecognizedLine(text: "Front-load washer", confidence: 0.9, boundingBox: .zero)
        ])

        #expect(suggestion.category == .appliance)
        #expect(suggestion.confidence == .high)
    }

    /// A plural matches the singular keyword through lemmatization.
    @Test func lemmaMatchesSingularKeyword() {
        let suggester = CategorySuggester(keywords: [.vehicle: ["tyre"]], embedding: nil)
        let suggestion = suggester.suggest(for: "two tyres fitted")

        #expect(suggestion.category == .vehicle)
        #expect(suggestion.confidence == .high)
    }

    /// Equal keyword scores stay uncertain and follow the earlier phrase.
    @Test func tiedKeywordsStayLowConfidence() throws {
        let suggestion = try CategorySuggester().suggest(for: "sofa and iphone")

        #expect(suggestion.category == .furniture)
        #expect(suggestion.confidence == .low)
    }

    /// A longer appliance phrase beats a single vehicle brand on the same receipt.
    @Test func longerKeywordWins() throws {
        let suggestion = try CategorySuggester().suggest(for: "honda washing machine")

        #expect(suggestion.category == .appliance)
        #expect(suggestion.confidence == .high)
    }
}

/// One receipt phrase and the category it should suggest.
struct SuggestionSample: Sendable {
    var text: String
    var category: ItemCategory
    var confidence: ParseConfidence
}

/// Phrases covering each category, letter case, and the fallback.
private let suggestionSamples: [SuggestionSample] = [
    SuggestionSample(text: "iPhone 15 128GB", category: .phone, confidence: .high),
    SuggestionSample(text: "IPHONE,", category: .phone, confidence: .high),
    SuggestionSample(text: "Samsung Galaxy A15", category: .phone, confidence: .high),
    SuggestionSample(text: "Google Pixel case", category: .phone, confidence: .high),
    SuggestionSample(text: "MacBook Air M2", category: .laptop, confidence: .high),
    SuggestionSample(text: "student laptop sleeve", category: .laptop, confidence: .high),
    SuggestionSample(text: "ThinkPad charger", category: .laptop, confidence: .high),
    SuggestionSample(text: "Front-load washer", category: .appliance, confidence: .high),
    SuggestionSample(text: "rice cooker", category: .appliance, confidence: .high),
    SuggestionSample(text: "microwave oven", category: .appliance, confidence: .high),
    SuggestionSample(text: "3 seater sofa", category: .furniture, confidence: .high),
    SuggestionSample(text: "wardrobe delivery", category: .furniture, confidence: .high),
    SuggestionSample(text: "Honda Fit tyre", category: .vehicle, confidence: .high),
    SuggestionSample(text: "engine oil change", category: .vehicle, confidence: .high),
    SuggestionSample(text: "Toyota service", category: .vehicle, confidence: .high),
    SuggestionSample(text: "", category: .other, confidence: .missing),
    SuggestionSample(text: "   ", category: .other, confidence: .missing),
    SuggestionSample(text: "desk lamp", category: .other, confidence: .low)
]
