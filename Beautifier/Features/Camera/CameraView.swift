import SwiftUI
import CoreVideo

struct CameraView: View {
    @StateObject private var camera = CameraService()
    @State private var processor = LiveProcessor()

    @State private var amount: Float = 0.5
    @State private var capturedImageData: Data?
    @State private var isNavigatingToEdit: Bool = false
    @State private var isCapturing: Bool = false

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if camera.authorizationDenied {
                    permissionDeniedView
                } else {
                    cameraPreview
                    controlsOverlay
                }
            }
            .navigationDestination(isPresented: $isNavigatingToEdit) {
                if let data = capturedImageData {
                    EditView(originalData: data)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                camera.start()
            }
            .onDisappear {
                camera.stop()
                processor.invalidateCache()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    camera.start()
                } else {
                    camera.stop()
                    processor.invalidateCache()
                }
            }
        }
    }

    private var cameraPreview: some View {
        MetalView(
            pixelBuffer: camera.latestPixelBuffer,
            amount: amount,
            processor: processor
        )
        .ignoresSafeArea()
        .accessibilityIdentifier("LiveCameraPreview")
    }

    private var controlsOverlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 20) {
                // Smoothing intensity slider
                VStack(spacing: 4) {
                    HStack {
                        Text("Smoothing")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(Int(amount * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }

                    Slider(value: $amount, in: 0...1)
                        .tint(.white)
                        .accessibilityIdentifier("LiveSmoothingSlider")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial.opacity(0.8))
                .cornerRadius(16)
                .padding(.horizontal, 20)

                // Shutter button
                HStack {
                    Spacer()

                    Button {
                        guard !isCapturing else { return }
                        isCapturing = true
                        camera.capturePhoto { data in
                            isCapturing = false
                            if let data {
                                capturedImageData = data
                                isNavigatingToEdit = true
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 72, height: 72)

                            Circle()
                                .fill(isCapturing ? Color.gray : Color.white)
                                .frame(width: 60, height: 60)
                        }
                    }
                    .disabled(isCapturing)
                    .accessibilityIdentifier("ShutterButton")

                    Spacer()
                }
                .padding(.bottom, 30)
            }
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.bold)

            Text("Please enable camera access in Settings to use the live beauty filter.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)

            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("OpenSettingsButton")
        }
        .padding()
    }
}
