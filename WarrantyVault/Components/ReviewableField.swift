//
//  ReviewableField.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Form row that highlights an uncertain parsed value in amber.
//

import SwiftUI

/// A form field plus the amber hint and the red validation message.
struct ReviewableField<Content: View>: View {
    let needsReview: Bool
    let errorMessage: String?
    let accessibilityIdentifier: String
    private let content: Content

    /// Creates a row. `needsReview` draws the amber treatment.
    init(
        needsReview: Bool,
        errorMessage: String? = nil,
        accessibilityIdentifier: String,
        @ViewBuilder content: () -> Content
    ) {
        self.needsReview = needsReview
        self.errorMessage = errorMessage
        self.accessibilityIdentifier = accessibilityIdentifier
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
            content
                .accessibilityHint(needsReview ? "Check this value. It was read from the receipt and may be wrong." : "")
            if needsReview {
                Text("Check this. It was read from the receipt.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.amber)
                    .accessibilityIdentifier("\(accessibilityIdentifier).review")
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("\(accessibilityIdentifier).error")
            }
        }
        .listRowBackground(needsReview ? Theme.Colors.amber.opacity(0.18) : nil)
    }
}
