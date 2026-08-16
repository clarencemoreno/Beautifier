import AVFoundation
import CoreVideo
import UIKit
import Combine

final class CameraService: NSObject, ObservableObject {
    @Published var isAuthorized: Bool = false
    @Published var authorizationDenied: Bool = false
    @Published var latestPixelBuffer: CVPixelBuffer?

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.beautifier.camera.session")
    private let videoQueue = DispatchQueue(label: "com.beautifier.camera.video", qos: .userInteractive)

    private var photoCompletion: ((Data?) -> Void)?
    private var isConfigured = false

    #if targetEnvironment(simulator)
    private var simulatorTimer: Timer?
    private var simulatorPixelBuffer: CVPixelBuffer?
    #endif

    override init() {
        super.init()
        #if targetEnvironment(simulator)
        prepareSimulatorFeed()
        #else
        checkPermissions()
        #endif
    }

    #if targetEnvironment(simulator)
    private func prepareSimulatorFeed() {
        DispatchQueue.main.async {
            self.isAuthorized = true
            self.authorizationDenied = false
        }
        // Load bundled face image and create a cached CVPixelBuffer
        guard let url = Bundle.main.url(forResource: "test_face", withExtension: "jpg") ??
                        Bundle.main.url(forResource: "sample_face", withExtension: "jpg"),
              let data = try? Data(contentsOf: url),
              let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else {
            return
        }
        self.simulatorPixelBuffer = createPixelBuffer(from: cgImage)
    }

    private func createPixelBuffer(from cgImage: CGImage) -> CVPixelBuffer? {
        let width = cgImage.width
        let height = cgImage.height
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferMetalCompatibilityKey: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        let pxData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pxData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
    #endif

    func checkPermissions() {
        #if targetEnvironment(simulator)
        DispatchQueue.main.async {
            self.isAuthorized = true
            self.authorizationDenied = false
        }
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.isAuthorized = true
                self.authorizationDenied = false
            }
            sessionQueue.async {
                self.configureSessionIfNeeded()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    self.authorizationDenied = !granted
                }
                if granted {
                    self.sessionQueue.async {
                        self.configureSessionIfNeeded()
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.isAuthorized = false
                self.authorizationDenied = true
            }
        @unknown default:
            break
        }
        #endif
    }

    private func configureSessionIfNeeded() {
        #if !targetEnvironment(simulator)
        guard !isConfigured else { return }

        session.beginConfiguration()
        session.sessionPreset = .high

        // Front-facing camera
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        // Video data output
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)

        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(videoOutput)

        // Photo output
        guard session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(photoOutput)
        photoOutput.isHighResolutionCaptureEnabled = true

        configureConnection()

        session.commitConfiguration()
        isConfigured = true
        #endif
    }

    private func configureConnection() {
        if let connection = videoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            } else {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }

        if let photoConnection = photoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if photoConnection.isVideoRotationAngleSupported(90) {
                    photoConnection.videoRotationAngle = 90
                }
            } else {
                if photoConnection.isVideoOrientationSupported {
                    photoConnection.videoOrientation = .portrait
                }
            }
            if photoConnection.isVideoMirroringSupported {
                photoConnection.isVideoMirrored = true
            }
        }
    }

    func start() {
        #if targetEnvironment(simulator)
        DispatchQueue.main.async {
            self.stopSimulatorFeed()
            self.simulatorTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                guard let self, let buffer = self.simulatorPixelBuffer else { return }
                self.latestPixelBuffer = buffer
            }
        }
        #else
        sessionQueue.async {
            guard self.isAuthorized else { return }
            self.configureSessionIfNeeded()
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
        #endif
    }

    func stop() {
        #if targetEnvironment(simulator)
        DispatchQueue.main.async {
            self.stopSimulatorFeed()
        }
        #else
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
        #endif
    }

    #if targetEnvironment(simulator)
    private func stopSimulatorFeed() {
        simulatorTimer?.invalidate()
        simulatorTimer = nil
    }
    #endif

    func capturePhoto(completion: @escaping (Data?) -> Void) {
        #if targetEnvironment(simulator)
        let url = Bundle.main.url(forResource: "test_face", withExtension: "jpg") ??
                  Bundle.main.url(forResource: "sample_face", withExtension: "jpg")
        let data = url.flatMap { try? Data(contentsOf: $0) }
        DispatchQueue.main.async {
            completion(data)
        }
        #else
        sessionQueue.async {
            guard self.session.isRunning else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.photoCompletion = completion
            let settings = AVCapturePhotoSettings()
            settings.isHighResolutionPhotoEnabled = true
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
        #endif
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        DispatchQueue.main.async {
            self.latestPixelBuffer = pixelBuffer
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = photo.fileDataRepresentation()
        let completion = self.photoCompletion
        self.photoCompletion = nil
        DispatchQueue.main.async {
            completion?(data)
        }
    }
}
