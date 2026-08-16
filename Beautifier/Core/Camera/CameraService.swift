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

    override init() {
        super.init()
        checkPermissions()
    }

    func checkPermissions() {
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
    }

    private func configureSessionIfNeeded() {
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

        // Configure deterministic portrait orientation and front-camera mirror
        configureConnection()

        session.commitConfiguration()
        isConfigured = true
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
        sessionQueue.async {
            guard self.isAuthorized else { return }
            self.configureSessionIfNeeded()
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func capturePhoto(completion: @escaping (Data?) -> Void) {
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
