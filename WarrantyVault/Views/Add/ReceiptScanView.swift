//
//  ReceiptScanView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Shows the chosen receipt while text recognition runs.
//

import SwiftUI

/// Review screen with a moving scan line over the receipt image.
struct ReceiptScanView: View {
    @Environment(AddItemViewModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            receiptPreview
            VStack(spacing: Theme.Spacing.small) {
                if model.isReading {
                    ProgressView()
                        .accessibilityIdentifier("add.scanProgress")
                }
                Text(model.isReading ? "Reading receipt…" : "Opening the form…")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.deepBlue)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(model.isReading ? "Reading receipt" : "Opening the form")
            .accessibilityIdentifier("add.scanStatus")
        }
        .screenPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Reading receipt")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: model.scanID) {
            await model.readReceipt()
        }
    }

    /// Receipt image with the scanning bar, or a static image when motion is reduced.
    private var receiptPreview: some View {
        ZStack {
            if let image = model.receiptImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        if model.isReading {
                            scanLine
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .stroke(Theme.Colors.deepBlue.opacity(0.35), lineWidth: Theme.Stroke.hairline)
                    )
                    .accessibilityLabel("Receipt preview")
                    .accessibilityIdentifier("add.receiptPreview")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Amber bar that travels down the receipt, unless the user prefers less motion.
    @ViewBuilder
    private var scanLine: some View {
        if reduceMotion {
            Theme.Colors.amber.opacity(0.18)
        } else {
            TimelineView(.animation) { context in
                GeometryReader { proxy in
                    let travel = scanOffset(at: context.date, height: proxy.size.height)
                    Rectangle()
                        .fill(Theme.Colors.amber.opacity(0.85))
                        .frame(height: 4)
                        .offset(y: travel)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    /// Position of the scan bar for `date`, looping from top to bottom.
    private func scanOffset(at date: Date, height: CGFloat) -> CGFloat {
        let duration = 1.6
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration) / duration
        return height * phase
    }
}
