//
//  TabNavigationStack.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Navigation stack shared by each tab, including typed route destinations.
//

import SwiftUI

/// A `NavigationStack` whose path is owned by `AppRouter`.
struct TabNavigationStack<Content: View>: View {
    private let title: String
    @Binding private var path: NavigationPath
    private let content: Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Creates a stack with a title and the shared route destinations.
    init(title: String, path: Binding<NavigationPath>, @ViewBuilder content: () -> Content) {
        self.title = title
        self._path = path
        self.content = content()
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(titleDisplayMode)
                .navigationDestination(for: Route.self) { route in
                    AppRouteView(route: route)
                }
        }
    }

    /// Large title at normal sizes, inline when text is an accessibility size.
    private var titleDisplayMode: NavigationBarItem.TitleDisplayMode {
        dynamicTypeSize.isAccessibilitySize ? .inline : .large
    }
}
