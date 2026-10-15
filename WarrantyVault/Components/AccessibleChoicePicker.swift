//
//  AccessibleChoicePicker.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-15.
//
//  Pickers that keep their labels and values readable at the largest Dynamic Type sizes.
//

import SwiftUI

/// A picker that lists every choice on its own line when text is an accessibility size.
struct AccessibleChoicePicker<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [Value]
    let optionTitle: (Value) -> String
    var optionSymbol: ((Value) -> String)? = nil
    let accessibilityIdentifier: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            expandedChoices
        } else {
            compactPicker
        }
    }

    /// Standard menu picker used at the default text sizes.
    private var compactPicker: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { option in
                optionLabel(option).tag(option)
            }
        }
        .font(Theme.Fonts.body)
        .accessibilityLabel(title)
        .accessibilityHint(String(localized: "Selects this option"))
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    /// Full-width rows so a long label is not squeezed into an ellipsis.
    private var expandedChoices: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text(title)
                .font(Theme.Fonts.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(options, id: \.self) { option in
                choiceButton(option)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    /// One selectable row. The title wraps instead of truncating.
    private func choiceButton(_ option: Value) -> some View {
        let isSelected = selection == option
        return Button {
            selection = option
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.small) {
                Text(optionTitle(option))
                    .font(Theme.Fonts.body)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Theme.Spacing.small)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(Theme.Fonts.body)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(optionTitle(option))
        .accessibilityHint(String(localized: "Selects this option"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("\(accessibilityIdentifier).\(optionIdentity(option))")
    }

    /// Symbol plus title when a symbol is provided, otherwise the title alone.
    @ViewBuilder
    private func optionLabel(_ option: Value) -> some View {
        if let optionSymbol {
            Label(optionTitle(option), systemImage: optionSymbol(option))
        } else {
            Text(optionTitle(option))
        }
    }

    /// Stable suffix for a choice identifier.
    private func optionIdentity(_ option: Value) -> String {
        String(describing: option)
    }
}

/// A date picker that shows the full date above a calendar at accessibility sizes.
struct AccessibleDatePicker: View {
    let title: String
    @Binding var selection: Date
    let accessibilityIdentifier: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            expandedDate
        } else {
            DatePicker(title, selection: $selection, displayedComponents: .date)
                .font(Theme.Fonts.body)
                .accessibilityLabel(title)
                .accessibilityHint(String(localized: "Sets this date"))
                .accessibilityIdentifier(accessibilityIdentifier)
        }
    }

    /// Written date plus a calendar, so the value is not a truncated button.
    private var expandedDate: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text(title)
                .font(Theme.Fonts.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(selection.formatted(date: .long, time: .omitted))
                .font(Theme.Fonts.body)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("\(accessibilityIdentifier).value")
            DatePicker(title, selection: $selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.graphical)
                .accessibilityLabel(title)
                .accessibilityHint(String(localized: "Sets this date"))
                .accessibilityIdentifier(accessibilityIdentifier)
        }
    }
}
