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
    @Environment(\.warrantyReminderScheduler) private var reminders
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
                .accessibilityLabel(String(localized: "OK"))
                .accessibilityHint(String(localized: "Dismisses this message"))
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
        if model.isLoading && model.items.isEmpty && model.loadError == nil {
            LoadingScreen(
                message: String(localized: "Loading warranties…"),
                accessibilityIdentifier: "screen.vault.loading"
            )
        } else if let loadError = model.loadError, model.items.isEmpty {
            PlaceholderScreen(
                title: String(localized: "Vault unavailable"),
                message: loadError,
                systemImage: "exclamationmark.triangle",
                symbolColor: Theme.Colors.amberInk,
                accessibilityIdentifier: "screen.vault.error",
                actionTitle: String(localized: "Try again"),
                actionIdentifier: "vault.retry",
                action: { model.reload(using: repository) }
            )
        } else if model.items.isEmpty {
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
                    title: String(localized: "Nothing saved yet"),
                    message: String(localized: "Receipts and warranty cards you import will be listed here."),
                    systemImage: AppTab.vault.systemImage,
                    symbolColor: Theme.Colors.deepBlue,
                    accessibilityIdentifier: "screen.vault.empty"
                )
            } else {
                PlaceholderScreen(
                    title: String(localized: "No warranties match"),
                    message: String(localized: "Try another filter or clear the search."),
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
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? Theme.Colors.deepBlue : .secondary)
        .accessibilityLabel(filter.title)
        .accessibilityHint("Shows warranties in this group")
        .accessibilityIdentifier("vault.filter.\(filter.rawValue)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .fixedSize(horizontal: true, vertical: true)
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
            archive(item)
        }
        .accessibilityAction(named: Text("Delete")) {
            delete(item)
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
        .accessibilityHint(String(localized: "Opens this warranty"))
        .accessibilityIdentifier("vault.menu.view")

        Button {
            router.push(.editWarranty(id: item.id), on: .vault)
        } label: {
            Label("Edit", systemImage: "square.and.pencil")
        }
        .accessibilityHint(String(localized: "Opens the form to change this warranty"))
        .accessibilityIdentifier("vault.menu.edit")

        Button {
            archive(item)
        } label: {
            Label("Archive", systemImage: "archivebox")
        }
        .accessibilityHint(String(localized: "Archives this warranty and cancels its reminders"))
        .accessibilityIdentifier("vault.menu.archive")

        Button(role: .destructive) {
            delete(item)
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .accessibilityHint(String(localized: "Deletes this warranty and its reminders"))
        .accessibilityIdentifier("vault.menu.delete")
    }

    /// Swipe action that archives the row.
    private func archiveButton(for item: WarrantyItem) -> some View {
        Button {
            archive(item)
        } label: {
            Label("Archive", systemImage: "archivebox")
        }
        .tint(Theme.Colors.amber)
        .accessibilityHint(String(localized: "Archives this warranty and cancels its reminders"))
        .accessibilityIdentifier("vault.archive.\(item.id.uuidString)")
    }

    /// Swipe action that deletes the row.
    private func deleteButton(for item: WarrantyItem) -> some View {
        Button(role: .destructive) {
            delete(item)
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .accessibilityHint(String(localized: "Deletes this warranty and its reminders"))
        .accessibilityIdentifier("vault.delete.\(item.id.uuidString)")
    }

    /// Pushes the warranty detail onto the vault stack.
    private func open(_ item: WarrantyItem) {
        withAnimation(.easeInOut(duration: 0.35)) {
            router.push(.warranty(id: item.id), on: .vault)
        }
    }

    /// Archives the warranty and cancels its reminders.
    private func archive(_ item: WarrantyItem) {
        Task {
            await model.archive(item, using: repository, reminders: reminders)
        }
    }

    /// Deletes the warranty and cancels its reminders.
    private func delete(_ item: WarrantyItem) {
        Task {
            await model.delete(item, using: repository, reminders: reminders)
        }
    }
}
