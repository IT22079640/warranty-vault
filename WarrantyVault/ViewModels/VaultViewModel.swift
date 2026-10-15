//
//  VaultViewModel.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Search, filter, and layout state for the vault list.
//

import Foundation
import Observation

/// Which vault layout the user last chose.
enum VaultLayout: String, CaseIterable, Identifiable {
    case list
    case grid

    /// Stable identifier for the layout control.
    var id: String { rawValue }

    /// Symbol for the button that switches away from this layout.
    var toggleSymbol: String {
        switch self {
        case .list:
            "square.grid.2x2"
        case .grid:
            "list.bullet"
        }
    }

    /// Spoken name of the layout the button will switch to.
    var toggleLabel: String {
        switch self {
        case .list:
            String(localized: "Show as grid")
        case .grid:
            String(localized: "Show as list")
        }
    }
}

/// Filter chips above the vault.
enum VaultFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case expiringSoon
    case expired

    /// Stable identifier for the chip.
    var id: String { rawValue }

    /// Title drawn on the chip.
    var title: String {
        switch self {
        case .all:
            String(localized: "All")
        case .active:
            WarrantyStatus.active.title
        case .expiringSoon:
            WarrantyStatus.expiringSoon.title
        case .expired:
            WarrantyStatus.expired.title
        }
    }

    /// Status passed to the repository. Nil keeps every unarchived state.
    var status: WarrantyStatus? {
        switch self {
        case .all:
            nil
        case .active:
            .active
        case .expiringSoon:
            .expiringSoon
        case .expired:
            .expired
        }
    }
}

/// Loads unarchived warranties and applies the vault's search, filter, and layout.
@MainActor
@Observable
final class VaultViewModel {
    /// Text in the vault search field.
    var searchText = ""
    /// Chip that limits the list by warranty status.
    var filter: VaultFilter = .all
    /// List or grid layout.
    var layout: VaultLayout = .list
    /// Warranties currently shown.
    private(set) var items: [WarrantyItem] = []
    /// True while the first load is in progress.
    private(set) var isLoading = true
    /// Message when the vault cannot be read.
    var loadError: String?
    /// Message when archive or delete fails.
    var actionError: String?

    /// Query for the current search box and chip. Archived rows stay hidden.
    func query(on date: Date = .now) -> WarrantyQuery {
        WarrantyQuery(
            searchText: searchText,
            status: filter.status,
            archiveScope: .unarchived,
            sort: .expiryDate,
            ascending: true,
            referenceDate: date
        )
    }

    /// True when the vault itself is empty, rather than a search or filter hiding rows.
    var showsFirstUseEmptyState: Bool {
        items.isEmpty
            && filter == .all
            && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Replaces `items` with the current query.
    func reload(using repository: WarrantyRepository?) {
        isLoading = true
        defer { isLoading = false }
        guard let repository else {
            items = []
            loadError = String(localized: "Warranty Vault could not open saved receipts.")
            return
        }
        do {
            items = try repository.items(matching: query())
            loadError = nil
        } catch {
            items = []
            loadError = String(localized: "Saved warranties could not be loaded.")
        }
    }

    /// Hides `item` from the vault, cancels its reminders, and refreshes the list.
    func archive(
        _ item: WarrantyItem,
        using repository: WarrantyRepository?,
        reminders: (any WarrantyReminderScheduling)? = nil
    ) async {
        guard let repository else {
            actionError = String(localized: "Warranty Vault could not open saved receipts.")
            return
        }
        do {
            try repository.setArchived(item, isArchived: true)
            await reminders?.cancel(identifiers: WarrantyReminderPlan.identifiers(for: item.id))
            reload(using: repository)
        } catch {
            actionError = String(localized: "That warranty could not be archived.")
        }
    }

    /// Removes `item` from the store, cancels its reminders, and refreshes the list.
    func delete(
        _ item: WarrantyItem,
        using repository: WarrantyRepository?,
        reminders: (any WarrantyReminderScheduling)? = nil
    ) async {
        guard let repository else {
            actionError = String(localized: "Warranty Vault could not open saved receipts.")
            return
        }
        do {
            let identifiers = WarrantyReminderPlan.identifiers(for: item.id)
            try repository.delete(item)
            await reminders?.cancel(identifiers: identifiers)
            reload(using: repository)
        } catch {
            actionError = String(localized: "That warranty could not be deleted.")
        }
    }

    /// Switches between the list and the adaptive grid.
    func toggleLayout() {
        layout = layout == .list ? .grid : .list
    }
}
