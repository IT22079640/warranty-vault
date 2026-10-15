//
//  AddView.swift
//  WarrantyVault
//
//  Created by Ama Hitiarachchi on 2026-10-13.
//
//  Starts a warranty from a photo, a PDF, or typed details. No camera.
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Root of the Add tab.
struct AddView: View {
    @Environment(AppRouter.self) private var router
    #if DEBUG
    @State private var model = AddItemViewModel(minimumReadDuration: SampleReceiptImage.scanHold)
    #else
    @State private var model = AddItemViewModel()
    #endif
    @State private var showSources = false
    @State private var showPhotos = false
    @State private var showFiles = false
    @State private var photoItem: PhotosPickerItem?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        @Bindable var router = router
        TabNavigationStack(title: AppTab.add.title, path: $router.addPath) {
            entry
        }
        .environment(model)
        .onChange(of: model.requestedStep) { _, step in
            guard let step else {
                return
            }
            withAnimation(.easeInOut(duration: 0.35)) {
                switch step {
                case .review:
                    router.push(.addReview, on: .add)
                case .form:
                    router.replacePath(with: [.addForm], on: .add)
                }
            }
            model.requestedStep = nil
        }
    }

    /// Import and manual-entry actions. The stack scrolls when Dynamic Type is large.
    private var entry: some View {
        ScrollView {
            VStack(spacing: dynamicTypeSize.isAccessibilitySize ? Theme.Spacing.medium : Theme.Spacing.large) {
                if let savedMessage = model.savedMessage {
                    Text(savedMessage)
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(Theme.Colors.deepBlue)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("add.savedMessage")
                }
                Text("Add a warranty from a receipt, or type the details yourself.")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if model.isImporting {
                    ProgressView("Opening receipt…")
                        .font(Theme.Fonts.body)
                        .accessibilityIdentifier("add.importProgress")
                }
                Button("Import receipt") {
                    if openBundledSampleIfRequested() {
                        return
                    }
                    showSources = true
                }
                .buttonStyle(VaultButtonStyle())
                .disabled(model.isImporting)
                .accessibilityLabel("Import receipt")
                .accessibilityHint("Opens Photos or Files. The camera is not used.")
                .accessibilityIdentifier("add.importReceipt")
                Button("Enter manually") {
                    model.startManualEntry()
                }
                .buttonStyle(.bordered)
                .tint(Theme.Colors.deepBlue)
                .disabled(model.isImporting)
                .accessibilityLabel("Enter manually")
                .accessibilityHint("Skips reading a receipt")
                .accessibilityIdentifier("add.enterManually")
            }
            .screenPadding()
            .padding(.bottom, Theme.Spacing.extraLarge)
            .frame(maxWidth: .infinity)
        }
        .confirmationDialog("Import a receipt", isPresented: $showSources, titleVisibility: .visible) {
            Button("Photo Library") {
                showPhotos = true
            }
            .accessibilityLabel(String(localized: "Photo Library"))
            .accessibilityHint(String(localized: "Chooses a receipt photo. The camera is not used."))
            .accessibilityIdentifier("add.photoLibrary")
            Button("Choose File") {
                showFiles = true
            }
            .accessibilityLabel(String(localized: "Choose File"))
            .accessibilityHint(String(localized: "Chooses a photo or a PDF from Files"))
            .accessibilityIdentifier("add.chooseFile")
            Button("Cancel", role: .cancel) {}
                .accessibilityLabel(String(localized: "Cancel"))
                .accessibilityHint(String(localized: "Closes the import choices"))
                .accessibilityIdentifier("add.importCancel")
        } message: {
            Text("Pick a photo or a PDF. Warranty Vault reads it on this device.")
        }
        .photosPicker(isPresented: $showPhotos, selection: $photoItem, matching: .images)
        .fileImporter(
            isPresented: $showFiles,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await model.importFile(result)
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else {
                return
            }
            Task {
                await model.importPhoto(item)
                photoItem = nil
            }
        }
        .alert("Could not import", isPresented: importAlertPresented) {
            Button("OK", role: .cancel) {
                model.importError = nil
            }
            .accessibilityLabel(String(localized: "OK"))
            .accessibilityHint(String(localized: "Dismisses this message"))
            .accessibilityIdentifier("add.importErrorOK")
        } message: {
            Text(model.importError ?? "")
        }
    }

    /// Starts OCR on the bundled sample when `-useSampleReceipt` is set. Release builds never take this path.
    private func openBundledSampleIfRequested() -> Bool {
        #if DEBUG
        guard SampleReceiptImage.isRequested else {
            return false
        }
        Task {
            await model.importBundledSample()
        }
        return true
        #else
        return false
        #endif
    }

    /// Presents the import alert only while an error string is set.
    private var importAlertPresented: Binding<Bool> {
        Binding(
            get: { model.importError != nil },
            set: { isPresented in
                if !isPresented {
                    model.importError = nil
                }
            }
        )
    }
}

extension PhotosPickerItem: PhotosImport {

    /// Loads the picked photo as data.
    func loadData() async throws -> Data? {
        try await loadTransferable(type: Data.self)
    }
}

#Preview {
    AddView()
        .environment(AppRouter())
}
