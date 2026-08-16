# Tasks — Live Camera Pipeline (v4)

> In order; verify each gate; no improvisation.

## §0 Baseline Cleanup & Spec Alignment

- [x] **0.1** In `Beautifier/Features/Edit/EditViewModel.swift`:
  - Align radius cap strictly to `min(max(baseRadius, 6.0 * scale), 15.0 * scale)` per `specs/image-editing/spec.md`.
  - Remove dead legacy `FaceSegmenter` fallback code.
  - **Verify:** `xcodebuild test` unit tests pass.

## §1 Camera Service (AVFoundation)

- [x] **1.1** Create `Core/Camera/CameraService.swift`:
  - Subclass `NSObject`, conform to `AVCaptureVideoDataOutputSampleBufferDelegate`, `AVCapturePhotoCaptureDelegate`.
  - Configure `AVCaptureSession` with `.high` preset on front camera.
  - Set `connection.videoOrientation = .portrait` (or `videoRotationAngle = 90` on iOS 17+) and `connection.isVideoMirrored = true`.
  - Video output format: `kCVPixelFormatType_32BGRA`.
  - Implement permission checks (`AVCaptureDevice.authorizationStatus`) and expose `@Published var isAuthorized: Bool`.
  - Serial queue for `start()` / `stop()` session lifecycle.
  - **Verify:** compiles and handles permissions cleanly.
- [x] **1.2** Add `AVCapturePhotoOutput` with `capturePhoto(completion:)` returning captured `Data`.
- [x] **1.3** Wire session `stop()` to `scenePhase != .active` and `onDisappear`.
  - **Verify:** Green camera indicator LED turns off immediately when backgrounded.

## §2 Metal Preview View

- [x] **2.1** Create `Features/Camera/MetalView.swift`:
  - `UIViewRepresentable` wrapping `MTKView`.
  - Coordinator owns a single `MTLCommandQueue` and renders via `RenderContext.shared`.
  - Implement aspect-fill centering transform (D6) without stretching.
  - **Verify:** Upright, un-stretched camera feed renders in Metal preview.
- [x] **2.2** Create `Features/Camera/CameraView.swift`:
  - Camera preview layer with smoothing intensity `Slider` (0%–100%) and circular shutter button.
  - Denied authorization overlay with direct "Open Settings" link.
- [x] **2.3** Update `BeautifierApp.swift` root to `CameraView` with NavigationStack handoff to `EditView`.
  - **Verify:** App launches straight into live camera feed.

## §3 Live Processor & Async Inference Queue

- [x] **3.1** Create `Core/Camera/LiveProcessor.swift`:
  - Dedicated serial inference queue `DispatchQueue(label: "com.beautifier.inference")`.
  - Non-blocking `isInferring` dispatch flag: incoming frame triggers inference without blocking render callback.
  - Publishes atomic `latestMask` and `latestFaceWidth`.
  - Implement cache invalidation rules (D3): clear mask when no face is found or bounding box shifts >15%.
  - Apply `SkinSmoothing.apply` using `latestMask` and bounded radius formula (D4).
  - **Verify:** compiles.
- [x] **3.2** Connect `LiveProcessor` into `MetalView` frame pipeline:
  - **Verify on device:** Live skin smoothing active; eyes, hair, lips, background sharp; render frame rate ≥ 30 FPS.

## §4 Shutter Handoff & Capture Flow

- [x] **4.1** Wire shutter button in `CameraView` to `camera.capturePhoto()`.
- [x] **4.2** On capture, transition to `EditView(originalData: data)` for fine-tuning and saving to Photos.
  - **Verify:** Captured image is high-resolution, correctly oriented, and editable.

## §5 Performance & Device Verification

- [x] **5.1** Instrument rolling FPS counter and assert ≥ 30.0 FPS on iPhone hardware.
- [x] **5.2** Verify unit and UI tests pass green.
- [x] **5.3** Append Week 4 acceptance records to `reqs.md` and tag `v0.4.0-live-camera`.
