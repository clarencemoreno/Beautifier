//
//  ContentView.swift
//  Beautifier
//
//  Created by ...
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var originalData: Data?
    @State private var originalPreviewImage: UIImage?
    @State private var previewImage: UIImage?
    @State private var previewCIImage: CIImage?
    @State private var smoothingAmount: Float = 0.6
    @State private var showingOriginalPreview = false
    @State private var isSaving = false
    @State private var saveMessage = ""
    @State private var errorMessage = ""
    @State private var showingErrorAlert = false

    private let previewMaxDimension: CGFloat = 2048

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                previewArea

                if previewImage != nil {
                    sliderSection
                }

                actionButtons

                if !saveMessage.isEmpty {
                    Text(saveMessage)
                        .font(.caption)
                        .foregroundStyle(saveMessage.hasPrefix("Error") ? .red : .green)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Beautifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                        Label("Pick Photo", systemImage: "photo.on.rectangle")
                    }
                    .disabled(isSaving)
                }
            }
            .onChange(of: pickerItem) { _, newValue in
                Task {
                    await loadPhoto(newValue)
                }
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var previewArea: some View {
        Group {
            if let image = currentDisplayImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 360, maxHeight: 480)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(radius: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 0.15, pressing: { pressing in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            showingOriginalPreview = pressing
                        }
                    }, perform: {})
                    .overlay(compareHint, alignment: .bottom)
            } else {
                ZStack {
                    Color.gray.opacity(0.12)
                        .frame(maxWidth: 360, maxHeight: 480)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    Text("Pick a photo to start")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
        }
        .animation(.default, value: currentDisplayImage)
    }

    private var compareHint: some View {
        Group {
            if currentDisplayImage != nil {
                Text(showingOriginalPreview ? "Original" : "Edited")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.55))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .padding(12)
            }
        }
    }

    private var sliderSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Smoothing")
                    .font(.headline)
                Spacer()
                Text("\(Int(smoothingAmount * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Slider(value: $smoothingAmount, in: 0...1) {
                Text("Smoothing")
            }
            .disabled(previewCIImage == nil)
            .onChange(of: smoothingAmount) { _, _ in
                Task {
                    await updatePreviewImage()
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { Task { await saveFullResolutionPhoto() } }) {
                Label("Save to Photos", systemImage: "square.and.arrow.down")
                    .font(.title3)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(previewCIImage == nil || isSaving)

            if isSaving {
                ProgressView("Saving...")
                    .frame(maxWidth: .infinity)
                    .padding(10)
            }
        }
    }

    private var currentDisplayImage: UIImage? {
        if showingOriginalPreview {
            return originalPreviewImage
        }
        return previewImage ?? originalPreviewImage
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else {
            return
        }

        originalData = nil
        originalPreviewImage = nil
        previewImage = nil
        previewCIImage = nil
        saveMessage = ""
        errorMessage = ""
        showingErrorAlert = false
        smoothingAmount = 0.6

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw ImageProcessing.Error.invalidImageData
            }

            originalData = data
            originalPreviewImage = try ImageProcessing.createUIImage(from: try ImageProcessing.downsampledPreviewCIImage(from: data, maxDimension: previewMaxDimension))
            previewCIImage = try ImageProcessing.downsampledPreviewCIImage(from: data, maxDimension: previewMaxDimension)
            await updatePreviewImage()
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }

    private func updatePreviewImage() async {
        guard let previewCIImage else {
            previewImage = nil
            return
        }

        do {
            if smoothingAmount <= 0 {
                previewImage = originalPreviewImage
            } else {
                previewImage = try ImageProcessing.smoothingPreview(for: previewCIImage, amount: smoothingAmount)
            }
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }

    private func saveFullResolutionPhoto() async {
        guard let data = originalData else { return }

        isSaving = true
        saveMessage = ""
        errorMessage = ""
        showingErrorAlert = false

        do {
            let normalizedImage = try ImageProcessing.normalizedImage(from: data)
            guard let ciImage = CIImage(image: normalizedImage) else {
                throw ImageProcessing.Error.invalidCIImage
            }

            let outputCIImage = try ImageProcessing.applySmoothing(to: ciImage, amount: smoothingAmount)
            let resultImage = try ImageProcessing.renderUIImage(from: outputCIImage, scale: normalizedImage.scale)

            try await PhotoSaver.save(resultImage)
            await MainActor.run {
                isSaving = false
                saveMessage = "Saved full-resolution photo."
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    saveMessage = ""
                }
            }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
    }
}

#Preview {
    ContentView()
}
