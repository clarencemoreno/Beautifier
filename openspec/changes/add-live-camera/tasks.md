# Tasks — Live Camera (v2)

> Rules unchanged: in order, verify each, no improvisation.
> PREREQUISITE: `v0.3.5-semantic-parser` tagged and §4 acceptance passed.

## §1 Camera Service

- [ ] **1.1** Create `Core/Camera/CameraService.swift`: NSObject +
  `AVCaptureVideoDataOutputSampleBufferDelegate`; serial `sessionQueue`;
  front wide-angle camera; `AVCaptureVideoDataOutput` with
  `kCVPixelFormatType_32BGRA`; also add `AVCapturePhotoOutput`.
  - **Verify:** compiles.
- [ ] **1.2** `start()` requests `AVCaptureDevice.requestAccess(for: .video)`,
  then `session.startRunning()` on `sessionQueue`; `stop()` likewise.
  - **Verify:** permission prompt appears; no crash on deny.

## §2 Metal Preview

- [ ] **2.1** Create `Features/Camera/MetalPreviewView.swift`:
  `UIViewRepresentable` wrapping `MTKView` (`framebufferOnly = false`,
  `device = MTLCreateSystemDefaultDevice()`); expose `render(ciImage:)`
  using `RenderContext`.
  - **Verify:** compiles.
- [ ] **2.2** Create `Features/Camera/CameraView.swift`: ZStack of
  MetalPreviewView + circular shutter button + close button;
  `CameraViewModel` pumps `CameraService` frames → preview (NO smoothing yet).
  - **Verify:** raw live feed renders on device.

## §3 Live Smoothing

- [ ] **3.1** Create `Core/Camera/LiveProcessor.swift` — exact code design §D20
  (plus `FaceDetector.faceWidth(in:)` helper returning normalized width).
  - **Verify:** compiles.
- [ ] **3.2** Wire frames: CameraService → LiveProcessor → MetalPreviewView;
  bind a slider overlay to `processor.amount`.
  - **Verify:** live smoothing visible; eyes/lips sharp; background untouched;
    ≥30fps on device.

## §4 Shutter & Polish

- [ ] **4.1** Shutter → `AVCapturePhotoOutput.capturePhoto` → `Data` →
  present `EditView(originalData: data)`.
  - **Verify:** captured still opens in editor with identical quality to the
    photo-import path.
- [ ] **4.2** Stop session in `onDisappear`; resume correctly on re-entry.
- [ ] **4.3** Append "Week 4" section to `reqs.md`; tick acceptance:
  - [ ] live smoothing on device ≥30fps
  - [ ] mask refresh invisible (no popping)
  - [ ] thermal-safe over a 5-minute session
  - [ ] camera LED off after closing the screen
- [ ] **4.4** Tag `v0.4.0-week4`; move `add-live-camera` and
  `add-semantic-skin-parser` to `openspec/changes/archive/`; update
  `openspec/STATUS.md`.
