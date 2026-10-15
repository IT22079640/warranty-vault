//
//  ExpiryRing.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Animated ring that shows how much warranty cover remains.
//

import SwiftUI

/// Circular progress ring with the day count in the center.
struct ExpiryRing: View {
    let daysRemaining: Int
    let progress: Double
    let status: WarrantyStatus

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawnProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(status.color.opacity(0.2), lineWidth: Theme.Spacing.small + 2)
            Circle()
                .trim(from: 0, to: drawnProgress)
                .stroke(
                    status.color,
                    style: StrokeStyle(lineWidth: Theme.Spacing.small + 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: Theme.Spacing.extraSmall) {
                Text(centerValue)
                    .font(Theme.Fonts.title2)
                    .foregroundStyle(status.color)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(centerCaption)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(Theme.Spacing.medium)
        }
        .frame(
            width: Theme.Spacing.extraLarge * 4,
            height: Theme.Spacing.extraLarge * 4
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WarrantySummary.daysLabel(daysRemaining))
        .accessibilityIdentifier("detail.expiryRing")
        .onAppear(perform: reveal)
        .onChange(of: progress) { _, newValue in
            drawnProgress = clamped(newValue)
        }
    }

    /// Number shown inside the ring.
    private var centerValue: String {
        daysRemaining < 0 ? "\(-daysRemaining)" : "\(daysRemaining)"
    }

    /// Word under the number, such as "days" or "overdue".
    private var centerCaption: String {
        if daysRemaining < 0 {
            return "overdue"
        }
        if daysRemaining == 1 {
            return "day"
        }
        return "days"
    }

    /// Draws the arc, skipping the motion when Reduce Motion is on.
    private func reveal() {
        let target = clamped(progress)
        guard !reduceMotion else {
            drawnProgress = target
            return
        }
        withAnimation(.easeOut(duration: 0.8)) {
            drawnProgress = target
        }
    }

    /// Keeps the trim inside the circle.
    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
