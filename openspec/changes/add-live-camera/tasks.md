# Tasks — Live Camera Pipeline

> **Rules:** Follow design.md exactly. Verify each step.

## §1 Camera Service (AVFoundation)

- [ ] **1.1** Create `Core/Camera/CameraService.swift`:
  - Subclass `NSObject`, conform to `AVCaptureVideoDataOutputSampleBufferDelegate`.
  - Setup `AVCaptureSession` with `.high` preset.
  - Add `AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)`.
  - Add `AVCaptureVideoDataOutput` with `[kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA]`.
  - Implement `captureOutput(_:didOutput:from:)` to extract `CVPixelBuffer` and publish it to `@Published var latestPixelBuffer`.
  - Add `start()` and `stop()` methods that run on a serial background queue.
  - **Verify:** compiles.

## §2 Metal Preview View

- [ ] **2.1** Create `Features/Camera/MetalView.swift`:
  - Wrap `MTKView` in a `UIViewRepresentable`.
  - In `makeUIView`, create an `MTKView` with `framebufferOnly = false` and `device = MTLCreateSystemDefaultDevice()`.
  - Create a `Coordinator` class conforming to `MTKViewDelegate`.
  - In `draw(in:)`, convert the `CVPixelBuffer` to `CIImage`, apply a temporary global `CIGaussianBlur` (to verify the pipeline), and render it to `view.currentDrawable.texture` using the `CIContext`.
  - **Verify:** compiles.

- [ ] **2.2** Create `Features/Camera/CameraView.swift`:
  - `@StateObject private var camera = CameraService()`.
  - ZStack containing `MetalView(pixelBuffer: $camera.latestPixelBuffer)` and a bottom overlay with a smoothing `Slider` and a circular shutter button.
  - Call `camera.start()` in `.onAppear` and `camera.stop()` in `.onDisappear`.
  - **Verify:** Running the app shows the raw, mirrored camera feed live on a physical device.

- [ ] **2.3** Update `BeautifierApp.swift` to launch directly into `CameraView()`.
  - **Verify:** App opens directly to the camera.

## §3 Live Processor & Temporal Caching

- [ ] **3.1** Create `Core/Camera/LiveProcessor.swift`:
  - Add `var cachedMask: CIImage?` and `var frameCount = 0`.
  - Implement `process(image: CIImage) -> CIImage`.
  - Every 4 frames (`frameCount % 4 == 0`), run `SkinParserML.skinMask(for:)` and update `cachedMask`.
  - For all frames, apply `SkinSmoothing.apply(to: mask: radius: amount:)` using the `cachedMask`.
  - **Verify:** compiles.

- [ ] **3.2** Wire the processor into `MetalView`:
  - Pass the `CVPixelBuffer` through `LiveProcessor` before rendering to the Metal drawable.
  - **Verify:** Moving the phone around shows real-time, skin-aware smoothing at ~60fps.

## §4 Shutter & Polish

- [ ] **4.1** Add `AVCapturePhotoOutput` to `CameraService`.
- [ ] **4.2** Implement `capturePhoto()` in `CameraService` that triggers a high-res still capture.
- [ ] **4.3** In `CameraView`, wire the shutter button to `capturePhoto()`.
- [ ] **4.4** When the photo is captured, convert it to `Data` and present the existing `EditView(originalData: data)` so the user can apply final tweaks and save it to the Photos library.
- [ ] **4.5** Tag the commit `v0.4.0-live-camera`.
