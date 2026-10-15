//
//  VaultView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Searchable vault of saved warranties, as a list or an adaptive grid.
//

import SwiftUI

/// Root of the Vault tab.
struct VaultView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.warrantyRepository) private var repository
    @Namespace private var vaultCards
    @State private var model = VaultViewModel()

    var body: some View {
        @Bindable var router = router
        @Bindable var model = model
        TabNavigationStack(title: AppTab.vault.title, path: $router.vaultPath) {
            VStack(spacing: Theme.Spacing.small) {
                filterChips
                content
            }
            .searchable(text: $model.searchText, prompt: "Search warranties")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    layoutButton
                }
            }
            .onAppear {
                model.reload(using: repository)
            }
            .onChange(of: model.searchText) { _, _ in
                model.reload(using: repository)
            }
            .onChange(of: model.filter) { _, _ in
                model.reload(using: repository)
            }
            .onChange(of: router.selectedTab) { _, tab in
                if tab == .vault {
                    model.reload(using: repository)
                }
            }
            .alert("Vault", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {
                    model.actionError = nil
                }
                .accessibilityIdentifier("vault.error.ok")
            } message: {
                Text(model.actionError ?? "")
            }
        }
        .environment(\.vaultGeometryNamespace, vaultCards)
    }

    /// Horizontal chips for All, Active, Expiring soon, and Expired.
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.small) {
                ForEach(VaultFilter.allCases) { filter in
                    chip(for: filter)
                }
            }
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.vertical, Theme.Spacing.extraSmall)
        }
        .accessibilityIdentifier("vault.filters")
    }

    /// List, adaptive grid, or an empty message.
    @ViewBuilder
    private var content: some View {
        if model.items.isEmpty {
            emptyState
        } else if model.layout == .list {
            warrantyList
        } else {
            warrantyGrid
        }
    }

    /// Full-width rows with archive and delete swipes.
    private var warrantyList: some View {
        List {
            ForEach(model.items) { item in
                warrantyButton(for: item)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(
                        top: Theme.Spacing.small,
                        leading: Theme.Spacing.medium,
                        bottom: Theme.Spacing.small,
                        trailing: Theme.Spacing.medium
                    ))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        deleteButton(for: item)
                        archiveButton(for: item)
                    }
            }
        }
        .listStyle(.plain)
        .accessibilityIdentifier("vault.list")
    }

    /// Columns that grow with the available width on iPhone and iPad.
    private var warrantyGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160), spacing: Theme.Spacing.medium)],
                spacing: Theme.Spacing.medium
            ) {
                ForEach(model.items) { item in
                    warrantyButton(for: item)
                }
            }
            .padding(Theme.Spacing.medium)
        }
        .accessibilityIdentifier("vault.grid")
    }

    /// First-use message, or a message when the current search and filter match nothing.
    private var emptyState: some View {
        Group {
            if model.showsFirstUseEmptyState {
                PlaceholderScreen(
                    title: "Nothing saved yet",
                    message: "Receipts and warranty cards you import will be listed here.",
                    systemImage: AppTab.vault.systemImage,
                    symbolColor: Theme.Colors.deepBlue,
                    accessibilityIdentifier: "screen.vault.empty"
                )
            } else {
                PlaceholderScreen(
                    title: "No warranties match",
                    message: "Try another filter or clear the search.",
                    systemImage: "line.3.horizontal.decrease.circle",
                    symbolColor: Theme.Colors.amber,
                    accessibilityIdentifier: "screen.vault.noResults"
                )
            }
        }
    }

    /// Switches between list and grid.
    private var layoutButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                model.toggleLayout()
            }
        } label: {
            Label(model.layout.toggleLabel, systemImage: model.layout.toggleSymbol)
        }
        .accessibilityLabel(model.layout.toggleLabel)
        .accessibilityHint("Changes how warranties are arranged")
        .accessibilityIdentifier("vault.layoutToggle")
    }

    /// True while a load, archive, or delete message should be shown.
    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { model.actionError != nil },
            set: { isPresented in
                if !isPresented {
                    model.actionError = nil
                }
            }
        )
    }

    /// One chip. The selected chip uses the deep blue tint.
    private func chip(for filter: VaultFilter) -> some View {
        let isSelected = model.filter == filter
        return Button {
            model.filter = filter
        } label: {
            Text(filter.title)
                .font(Theme.Fonts.subheadline)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? Theme.Colors.deepBlue : .secondary)
        .accessibilityLabel(filter.title)
        .accessibilityHint("Shows warranties in this group")
        .accessibilityIdentifier("vault.filter.\(filter.rawValue)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Opens the detail screen with the shared card animation.
    private func warrantyButton(for item: WarrantyItem) -> some View {
        Button {
            open(item)
        } label: {
            VaultWarrantyCard(item: item)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this warranty")
        .accessibilityIdentifier("vault.open.\(item.id.uuidString)")
        .accessibilityAction(named: Text("Archive")) {
            model.archive(item, using: repository)
        }
        .accessibilityAction(named: Text("Delete")) {
            model.delete(item, using: repository)
        }
        .contextMenu {
            menu(for: item)
        }
    }

    /// View, edit, archive, and delete for both layouts.
    @ViewBuilder
    private func menu(for item: WarrantyItem) -> some View {
        Button {
            open(item)
        } label: {
            Label("View", systemImage: "eye")
        }
        .accessibilityIdentifier("vault.menu.view")

        Button {
            router.push(.editWarranty(id: item.id), on: .vault)
        } label: {
            Label("Edit", systemImage: "square.and.pencil")
        }
        .accessibilityIdentifier("vault.menu.edit")

        Button {
            model.archive(item, using: repository)
        } label: {
            Label("Archive", systemImage: "archivebox")
        }
        .accessibilityIdentifier("vault.menu.archive")

        Button(role: .destructive) {
            model.delete(item, using: repository)
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .accessibilityIdentifier("vault.menu.delete")
    }

    /// Swipe action that archives the row.
    private func archiveButton(for item: WarrantyItem) -> some View {
        Button {
            model.archive(item, using: repository)
        } label: {
            Label("Archive", systemImage: "archivebox")
        }
        .tint(Theme.Colors.amber)
        .accessibilityIdentifier("vault.archive.\(item.id.uuidString)")
    }

    /// Swipe action that deletes the row.
    private func deleteButton(for item: WarrantyItem) -> some View {
        Button(role: .destructive) {
            model.delete(item, using: repository)
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .accessibilityIdentifier("vault.delete.\(item.id.uuidString)")
    }

    /// Pushes the warranty detail onto the vault stack.
    private func open(_ item: WarrantyItem) {
        withAnimation(.easeInOut(duration: 0.35)) {
            router.push(.warranty(id: item.id), on: .vault)
        }
    }
}
