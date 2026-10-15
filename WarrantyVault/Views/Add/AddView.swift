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
    @State private var model = AddItemViewModel()
    @State private var showSources = false
    @State private var showPhotos = false
    @State private var showFiles = false
    @State private var photoItem: PhotosPickerItem?

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

    /// Import and manual-entry actions.
    private var entry: some View {
        VStack(spacing: Theme.Spacing.large) {
            if let savedMessage = model.savedMessage {
                Text(savedMessage)
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(Theme.Colors.deepBlue)
                    .accessibilityIdentifier("add.savedMessage")
            }
            Text("Add a warranty from a receipt, or type the details yourself.")
                .font(Theme.Fonts.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if model.isImporting {
                ProgressView("Opening receipt…")
                    .font(Theme.Fonts.body)
                    .accessibilityIdentifier("add.importProgress")
            }
            Button("Import receipt") {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog("Import a receipt", isPresented: $showSources, titleVisibility: .visible) {
            Button("Photo Library") {
                showPhotos = true
            }
            .accessibilityIdentifier("add.photoLibrary")
            Button("Choose File") {
                showFiles = true
            }
            .accessibilityIdentifier("add.chooseFile")
            Button("Cancel", role: .cancel) {}
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
            .accessibilityIdentifier("add.importErrorOK")
        } message: {
            Text(model.importError ?? "")
        }
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
