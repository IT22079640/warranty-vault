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

    /// Creates a stack with a large title and placeholder destinations for `Route`.
    init(title: String, path: Binding<NavigationPath>, @ViewBuilder content: () -> Content) {
        self.title = title
        self._path = path
        self.content = content()
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: Route.self) { route in
                    RoutePlaceholderView(route: route)
                }
        }
    }
}
