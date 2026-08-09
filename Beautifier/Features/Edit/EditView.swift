import SwiftUI

struct EditView: View {
    @StateObject private var viewModel: EditViewModel

    init(originalData: Data) {
        _viewModel = StateObject(wrappedValue: EditViewModel(originalData: originalData))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let image = viewModel.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .gesture(
                        LongPressGesture(minimumDuration: 0.1)
                            .onEnded { _ in
                                withAnimation {
                                    viewModel.showingOriginal.toggle()
                                }
                                viewModel.renderPreview()
                            }
                    )
            } else {
                ProgressView("Loading…")
            }

            Divider()

            VStack(spacing: 16) {
                if viewModel.noFaceDetected {
                    Text("No face detected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("NoFaceDetectedText")
                }

                Slider(value: $viewModel.amount, in: 0...1) {
                    Text("Smoothing: \(Int(viewModel.amount * 100))%")
                }
                .disabled(viewModel.noFaceDetected)
                .accessibilityIdentifier("SmoothingSlider")

                Button {
                    Task {
                        await viewModel.save()
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Label("Save to Photos", systemImage: "square.and.arrow.down")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("SaveButton")
            }
            .padding()
        }
        .navigationTitle("Edit")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.showMaskDebug.toggle()
                    viewModel.renderPreview()
                } label: {
                    Image(systemName: viewModel.showMaskDebug ? "eye.fill" : "eye")
                }
                .accessibilityIdentifier("MaskDebugButton")
            }
        }
        .alert(viewModel.alert?.title ?? "", isPresented: .constant(viewModel.alert != nil)) {
            Button("OK") {
                viewModel.alert = nil
            }
        } message: {
            if let alert = viewModel.alert {
                Text(alert.message)
            }
        }
    }
}
