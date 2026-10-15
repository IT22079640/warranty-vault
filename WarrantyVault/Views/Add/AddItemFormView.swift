//
//  AddItemFormView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-14.
//
//  Editable warranty form filled from a receipt or typed by hand.
//

import SwiftUI

/// Form for the product, shop, date, price, category, cover length, and notes.
struct AddItemFormView: View {
    @Environment(AddItemViewModel.self) private var model
    @Environment(AppRouter.self) private var router
    @Environment(\.warrantyRepository) private var repository
    @Environment(\.warrantyReminderScheduler) private var reminders
    @Environment(\.reminderPreferences) private var preferences
    @FocusState private var focusedField: Field?

    var body: some View {
        @Bindable var model = model
        Form {
            if let readNotice = model.readNotice {
                Section {
                    Text(readNotice)
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(Theme.Colors.amber)
                        .accessibilityIdentifier("add.readNotice")
                }
            }
            productSection(model)
            purchaseSection(model)
            coverSection(model)
            if let saveError = model.saveError {
                Section {
                    Text(saveError)
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("add.saveError")
                }
            }
        }
        .navigationTitle(model.isEditing ? "Edit warranty" : "Warranty details")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            saveButton
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
                .accessibilityLabel("Done")
                .accessibilityHint("Hides the keyboard")
                .accessibilityIdentifier("add.keyboardDone")
            }
        }
    }

    /// Product name and category.
    private func productSection(_ model: AddItemViewModel) -> some View {
        @Bindable var model = model
        return Section("Product") {
            ReviewableField(
                needsReview: false,
                errorMessage: model.validation.productName,
                accessibilityIdentifier: "add.productName"
            ) {
                TextField("Product name", text: $model.productName)
                    .font(Theme.Fonts.body)
                    .focused($focusedField, equals: .name)
                    .accessibilityLabel("Product name")
                    .accessibilityIdentifier("add.productName")
            }
            ReviewableField(
                needsReview: model.categoryNeedsReview,
                accessibilityIdentifier: "add.category"
            ) {
                Picker("Category", selection: categoryBinding) {
                    ForEach(ItemCategory.allCases) { category in
                        Label(category.title, systemImage: category.symbolName).tag(category)
                    }
                }
                .font(Theme.Fonts.body)
                .accessibilityLabel("Category")
                .accessibilityIdentifier("add.category")
            }
        }
    }

    /// Shop, date, and amount. Uncertain parsed values are amber.
    private func purchaseSection(_ model: AddItemViewModel) -> some View {
        Section("Purchase") {
            ReviewableField(
                needsReview: model.storeNeedsReview,
                accessibilityIdentifier: "add.store"
            ) {
                TextField("Store", text: storeBinding)
                    .font(Theme.Fonts.body)
                    .focused($focusedField, equals: .store)
                    .accessibilityLabel("Store")
                    .accessibilityIdentifier("add.store")
            }
            ReviewableField(
                needsReview: model.dateNeedsReview,
                accessibilityIdentifier: "add.purchaseDate"
            ) {
                DatePicker("Purchase date", selection: dateBinding, displayedComponents: .date)
                    .font(Theme.Fonts.body)
                    .accessibilityLabel("Purchase date")
                    .accessibilityIdentifier("add.purchaseDate")
            }
            ReviewableField(
                needsReview: model.amountNeedsReview,
                errorMessage: model.validation.amount,
                accessibilityIdentifier: "add.amount"
            ) {
                TextField("Amount", text: amountBinding)
                    .font(Theme.Fonts.body)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .amount)
                    .accessibilityLabel("Amount")
                    .accessibilityIdentifier("add.amount")
            }
        }
    }

    /// Warranty length and notes.
    private func coverSection(_ model: AddItemViewModel) -> some View {
        @Bindable var model = model
        return Section("Warranty") {
            Picker("Warranty length", selection: $model.warrantyLength) {
                ForEach(WarrantyLengthOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .font(Theme.Fonts.body)
            .accessibilityLabel("Warranty length")
            .accessibilityIdentifier("add.warrantyLength")
            if model.warrantyLength == .custom {
                ReviewableField(
                    needsReview: false,
                    errorMessage: model.validation.warrantyLength,
                    accessibilityIdentifier: "add.customMonths"
                ) {
                    TextField("Months", text: $model.customMonths)
                        .font(Theme.Fonts.body)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .months)
                        .accessibilityLabel("Custom warranty months")
                        .accessibilityIdentifier("add.customMonths")
                }
            } else if let warrantyLength = model.validation.warrantyLength {
                Text(warrantyLength)
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(.red)
            }
            TextField("Notes", text: $model.notes, axis: .vertical)
                .font(Theme.Fonts.body)
                .lineLimit(3...6)
                .focused($focusedField, equals: .notes)
                .accessibilityLabel("Notes")
                .accessibilityIdentifier("add.notes")
        }
    }

    /// Saves through the repository, then leaves the form.
    private var saveButton: some View {
        Button(action: save) {
            if model.isSaving {
                ProgressView()
            } else {
                Text("Save")
            }
        }
        .buttonStyle(VaultButtonStyle())
        .disabled(model.isSaving)
        .screenPadding()
        .background(.bar)
        .accessibilityLabel("Save")
        .accessibilityHint("Saves this warranty in the vault")
        .accessibilityIdentifier("add.save")
    }

    /// Validates, saves, schedules reminders, and plays haptic feedback.
    private func save() {
        focusedField = nil
        Task {
            let saved = await model.save(
                using: repository,
                reminders: reminders,
                preferences: preferences
            )
            guard saved else {
                return
            }
            withAnimation(.easeInOut(duration: 0.35)) {
                if model.isEditing {
                    router.pop(for: .vault)
                } else {
                    router.popToRoot(for: .add)
                }
            }
        }
    }

    /// Store text that clears the amber hint when edited.
    private var storeBinding: Binding<String> {
        Binding(get: { model.store }, set: { model.setStore($0) })
    }

    /// Purchase date that clears the amber hint when edited.
    private var dateBinding: Binding<Date> {
        Binding(get: { model.purchaseDate }, set: { model.setPurchaseDate($0) })
    }

    /// Amount text that clears the amber hint when edited.
    private var amountBinding: Binding<String> {
        Binding(get: { model.amountText }, set: { model.setAmountText($0) })
    }

    /// Category that clears the amber hint when edited.
    private var categoryBinding: Binding<ItemCategory> {
        Binding(get: { model.category }, set: { model.setCategory($0) })
    }
}

/// Keyboard focus targets on the warranty form.
private enum Field: Hashable {
    case name
    case store
    case amount
    case months
    case notes
}
