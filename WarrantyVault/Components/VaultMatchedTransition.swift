//
//  VaultMatchedTransition.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Shared geometry so a vault card can grow into the detail header.
//

import SwiftUI

/// Namespace created above the vault navigation stack and read by its destinations.
private struct VaultGeometryNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    /// Geometry namespace for the vault card to detail transition. Nil outside the Vault tab.
    var vaultGeometryNamespace: Namespace.ID? {
        get { self[VaultGeometryNamespaceKey.self] }
        set { self[VaultGeometryNamespaceKey.self] = newValue }
    }
}

/// Applies `matchedGeometryEffect` when the vault namespace is in the environment.
private struct VaultMatchedTransition: ViewModifier {
    let id: UUID
    let isSource: Bool
    @Environment(\.vaultGeometryNamespace) private var namespace
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Matches this view to the other view that uses the same warranty id.
    ///
    /// Accessibility sizes skip the match so the detail header can grow with the text.
    @ViewBuilder
    func body(content: Content) -> some View {
        if let namespace, !dynamicTypeSize.isAccessibilitySize {
            content.matchedGeometryEffect(id: id, in: namespace, isSource: isSource)
        } else {
            content
        }
    }
}

extension View {
    /// Links this view to the vault card or detail header that shares `id`.
    func vaultMatchedTransition(id: UUID, isSource: Bool) -> some View {
        modifier(VaultMatchedTransition(id: id, isSource: isSource))
    }
}
