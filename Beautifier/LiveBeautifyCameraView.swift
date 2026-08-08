//
//  LiveBeautifyCameraView.swift
//  Beautifier
//

import SwiftUI
import Combine
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import MetalKit

/// Real-time live camera feed with realtime CoreImage skin smoothing & snapshot capture
struct LiveBeautifyCameraView: View {
    @StateObject private var cameraModel = CameraFilterManager()
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let previewImage = cameraModel.currentFrame {
                Image(uiImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
            } else {
                ProgressView("Starting Simulated Video Feed...")
                    .foregroundColor(.white)
            }

            // Controls Overlay
            VStack {
                // Top Bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                    if cameraModel.isSimulator {
                        Text("SIMULATED VIDEO FEED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.8))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .padding(.trailing, 16)
                    }
                }

                Spacer()

                // Live Smoothing Controls & Capture Button
                VStack(spacing: 20) {
                    // Smooth Intensity Slider
                    VStack(spacing: 6) {
                        Text("Skin Smoothing Intensity: \(Int(cameraModel.smoothRadius * 10))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Slider(value: $cameraModel.smoothRadius, in: 0.0...20.0)
                            .accentColor(.green)
                            .padding(.horizontal, 40)
                            .onChange(of: cameraModel.smoothRadius) { _, _ in
                                cameraModel.processCurrentFrame()
                            }
                    }
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
                    .padding(.horizontal, 24)

                    // Capture Snapshot Button
                    Button(action: {
                        if let captured = cameraModel.captureSnapshot() {
                            onCapture(captured)
                            dismiss()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 76, height: 76)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 64, height: 64)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            cameraModel.startSession()
        }
        .onDisappear {
            cameraModel.stopSession()
        }
    }
}

// MARK: - Camera & Real-Time Filter Manager

final class CameraFilterManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var currentFrame: UIImage?
    @Published var smoothRadius: Float = 8.0
    @Published var isSimulator: Bool = false

    private let captureSession = AVCaptureSession()
    private let context = CIContext()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var timer: Timer?
    private var baseImage: UIImage?

    override init() {
        super.init()
        #if targetEnvironment(simulator)
        isSimulator = true
        loadSampleFaceImage()
        #else
        setupCamera()
        #endif
    }

    private func loadSampleFaceImage() {
        if let path = Bundle.main.path(forResource: "sample_face", ofType: "jpg"),
           let img = UIImage(contentsOfFile: path) {
            baseImage = img
        } else {
            // Programmatic portrait generator if asset fails
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 600))
            baseImage = renderer.image { ctx in
                UIColor.systemTeal.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 600))
            }
        }
    }

    private func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .hd1280x720

            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ??
                                AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera) else {
                self.captureSession.commitConfiguration()
                return
            }

            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
            }

            self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frame.queue"))
            
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            }

            self.captureSession.commitConfiguration()
        }
    }

    func startSession() {
        if isSimulator {
            // Start simulated video timer loop (30 FPS)
            processCurrentFrame()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                self?.processCurrentFrame()
            }
        } else {
            sessionQueue.async { [weak self] in
                if self?.captureSession.isRunning == false {
                    self?.captureSession.startRunning()
                }
            }
        }
    }

    func stopSession() {
        if isSimulator {
            timer?.invalidate()
            timer = nil
        } else {
            sessionQueue.async { [weak self] in
                if self?.captureSession.isRunning == true {
                    self?.captureSession.stopRunning()
                }
            }
        }
    }

    func processCurrentFrame() {
        guard isSimulator, let original = baseImage, let ciImage = CIImage(image: original) else { return }

        // Apply real-time skin smoothing filter
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = ciImage
        blurFilter.radius = smoothRadius

        guard let blurred = blurFilter.outputImage else { return }

        let blendFilter = CIFilter.sourceOverCompositing()
        blendFilter.backgroundImage = ciImage
        blendFilter.inputImage = blurred

        guard let outputImage = blendFilter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: ciImage.extent) else { return }

        let filteredImage = UIImage(cgImage: cgImage)
        DispatchQueue.main.async {
            self.currentFrame = filteredImage
        }
    }

    func captureSnapshot() -> UIImage? {
        return currentFrame
    }

    // AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Apply skin smoothing filter on live video frame
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = ciImage
        blurFilter.radius = smoothRadius

        guard let blurred = blurFilter.outputImage else { return }

        let blendFilter = CIFilter.sourceOverCompositing()
        blendFilter.backgroundImage = ciImage
        blendFilter.inputImage = blurred

        guard let outputImage = blendFilter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: ciImage.extent) else { return }

        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
        DispatchQueue.main.async {
            self.currentFrame = uiImage
        }
    }
}
