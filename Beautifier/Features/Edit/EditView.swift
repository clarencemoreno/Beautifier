import SwiftUI

struct EditView: View {
    @StateObject private var viewModel: EditViewModel

    init(originalData: Data, initialAmount: Float = 0.5) {
        _viewModel = StateObject(wrappedValue: EditViewModel(originalData: originalData, initialAmount: initialAmount))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let image = viewModel.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .onLongPressGesture(minimumDuration: 0.1, pressing: { isPressing in
                        viewModel.showingOriginal = isPressing
                        viewModel.renderPreview()
                    }, perform: {})
            } else {
                ProgressView("Loading…")
            }

            Divider()

            VStack(spacing: 16) {
                if viewModel.isDetectingFace {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Detecting face skin...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.noFaceDetected {
                    Text("No face detected (global fallback active)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("NoFaceDetectedText")
                }

                Slider(value: $viewModel.amount, in: 0...1) {
                    Text("Smoothing: \(Int(viewModel.amount * 100))%")
                }
                .disabled(viewModel.noFaceDetected)
                .onChange(of: viewModel.amount) { _, _ in
                    viewModel.renderPreview()
                }
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
        .alert(item: $viewModel.alert) { alertState in
            Alert(
                title: Text(alertState.title),
                message: Text(alertState.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
