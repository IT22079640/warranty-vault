//
//  InsightsViewModel.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  Loads unarchived warranties for the Insights charts.
//

import Foundation
import Observation

/// Fetches the warranties that Insights charts and the summary card describe.
@MainActor
@Observable
final class InsightsViewModel {
    private(set) var summary: InsightsSummary = .empty
    private(set) var isLoading = true
    var loadError: String?

    /// Rebuilds the summary from unarchived warranties.
    func reload(
        using repository: WarrantyRepository?,
        on date: Date = .now,
        calendar: Calendar = .current
    ) {
        isLoading = true
        defer { isLoading = false }
        guard let repository else {
            summary = .empty
            loadError = String(localized: "Warranty Vault could not open saved receipts.")
            return
        }
        do {
            let items = try repository.items(
                matching: WarrantyQuery(archiveScope: .unarchived, referenceDate: date)
            )
            summary = InsightsSummary.make(items: items, on: date, calendar: calendar)
            loadError = nil
        } catch {
            summary = .empty
            loadError = String(localized: "Insights could not be loaded.")
        }
    }
}
