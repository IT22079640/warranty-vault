//
//  OnboardingView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  Three-page introduction shown the first time the app opens.
//

import SwiftUI

/// UserDefaults key that records a finished introduction.
enum OnboardingStorage {
    /// True after the user finishes or skips the introduction.
    static let finishedKey = "hasFinishedOnboarding"
}

/// Paged introduction for saving receipts and expiry reminders.
struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var page = 0

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            HStack {
                Spacer()
                Button(String(localized: "Skip")) {
                    onFinish()
                }
                .font(Theme.Fonts.body)
                .accessibilityLabel(String(localized: "Skip"))
                .accessibilityHint(String(localized: "Closes the introduction and opens the vault"))
                .accessibilityIdentifier("onboarding.skip")
            }
            .screenPadding()

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPage(page: page)
                        .tag(index)
                        .accessibilityIdentifier("onboarding.page.\(index)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .clipped()

            HStack(spacing: Theme.Spacing.small) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == page ? Theme.Colors.deepBlue : Color.secondary.opacity(0.35))
                        .frame(width: Theme.Spacing.small, height: Theme.Spacing.small)
                }
            }
            .padding(.vertical, Theme.Spacing.small)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(pageLabel)
            .accessibilityIdentifier("onboarding.pageIndicator")

            Button(page == pages.count - 1 ? String(localized: "Get started") : String(localized: "Next")) {
                advance()
            }
            .buttonStyle(VaultButtonStyle())
            .screenPadding()
            .accessibilityLabel(page == pages.count - 1 ? String(localized: "Get started") : String(localized: "Next"))
            .accessibilityHint(
                page == pages.count - 1
                    ? String(localized: "Opens the vault")
                    : String(localized: "Shows the next introduction page")
            )
            .accessibilityIdentifier(page == pages.count - 1 ? "onboarding.getStarted" : "onboarding.next")
        }
        .background(Color(.systemBackground))
        .accessibilityIdentifier("screen.onboarding")
    }

    /// The three introduction pages, in order.
    private var pages: [OnboardingPageContent] {
        [
            OnboardingPageContent(
                symbol: "archivebox",
                title: String(localized: "Every warranty in one place"),
                message: String(localized: "Keep the receipt and the cover dates for the things you buy, so a paper slip is not the only copy.")
            ),
            OnboardingPageContent(
                symbol: "doc.viewfinder",
                title: String(localized: "Import a receipt"),
                message: String(localized: "Choose a photo or a PDF from Photos or Files. Warranty Vault reads it on this device. There is no camera.")
            ),
            OnboardingPageContent(
                symbol: "bell.badge",
                title: String(localized: "A reminder before it ends"),
                message: String(localized: "Turn on reminders and Warranty Vault will notify you 30 days, 7 days, and 1 day before cover ends.")
            )
        ]
    }

    /// Spoken position, such as "Page 1 of 3".
    private var pageLabel: String {
        LocalizedFormat.string("Page %lld of %lld", Int64(page + 1), Int64(pages.count))
    }

    /// Moves to the next page, or finishes on the last page.
    private func advance() {
        if page < pages.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) {
                page += 1
            }
        } else {
            onFinish()
        }
    }
}

/// Copy and symbol for one introduction page.
struct OnboardingPageContent: Equatable {
    /// SF Symbol shown above the title.
    var symbol: String
    /// Page heading.
    var title: String
    /// Sentence under the heading.
    var message: String
}

/// One scrolling introduction page so large text is not clipped.
private struct OnboardingPage: View {
    let page: OnboardingPageContent
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(spacing: dynamicTypeSize.isAccessibilitySize ? Theme.Spacing.small : Theme.Spacing.large) {
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: page.symbol)
                        .font(Theme.Fonts.largeTitle)
                        .foregroundStyle(Theme.Colors.deepBlue)
                        .accessibilityHidden(true)
                }
                Text(page.title)
                    .font(dynamicTypeSize.isAccessibilitySize ? Theme.Fonts.title2 : Theme.Fonts.title)
                    .foregroundStyle(Theme.Colors.deepBlue)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(page.message)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .screenPadding()
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(page.title). \(page.message)")
    }
}
