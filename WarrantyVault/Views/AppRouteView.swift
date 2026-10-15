//
//  AppRouteView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Chooses the screen for a typed route.
//

import SwiftUI

/// Destination for every `Route`, including the add-item steps.
struct AppRouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case .receipt:
            RoutePlaceholderView(route: route)
        case .warranty(let id):
            ItemDetailView(itemID: id)
        case .addReview:
            ReceiptScanView()
        case .addForm:
            AddItemFormView()
        case .editWarranty(let id):
            EditWarrantyView(itemID: id)
        case .scheduledReminders:
            ScheduledRemindersView()
        }
    }
}
