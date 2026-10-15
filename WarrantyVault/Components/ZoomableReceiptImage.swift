//
//  ZoomableReceiptImage.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Receipt photo that supports pinch zoom and a double tap.
//

import SwiftUI

/// A receipt image that scales between its fitted size and four times larger.
struct ZoomableReceiptImage: View {
    let image: UIImage

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1
    @State private var gestureScale: CGFloat = 1

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(displayScale)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.Spacing.extraLarge * 6)
            .clipped()
            .contentShape(Rectangle())
            .gesture(magnify)
            .simultaneousGesture(TapGesture(count: 2).onEnded { toggleZoom() })
            .accessibilityLabel("Receipt photo")
            .accessibilityHint("Double tap to zoom. Pinch to zoom in or out.")
            .accessibilityIdentifier("detail.receiptImage")
            .accessibilityAddTraits(.isImage)
            .accessibilityZoomAction { action in
                adjustScale(zoomingIn: action.direction == .zoomIn)
            }
    }

    /// Combined scale from the last pinch and the pinch currently in progress.
    private var displayScale: CGFloat {
        clamped(scale * gestureScale)
    }

    /// Tracks a pinch and stores the result when the fingers lift.
    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                gestureScale = value.magnification
            }
            .onEnded { value in
                scale = clamped(scale * value.magnification)
                gestureScale = 1
            }
    }

    /// Switches between the fitted size and double size.
    private func toggleZoom() {
        let next: CGFloat = scale > 1.05 ? 1 : 2
        gestureScale = 1
        guard !reduceMotion else {
            scale = next
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            scale = next
        }
    }

    /// Moves the scale one step for VoiceOver zoom.
    private func adjustScale(zoomingIn: Bool) {
        if zoomingIn {
            scale = clamped(scale + 0.5)
        } else {
            scale = clamped(scale - 0.5)
        }
        gestureScale = 1
    }

    /// Keeps zoom between the fitted size and four times larger.
    private func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, 1), 4)
    }
}
