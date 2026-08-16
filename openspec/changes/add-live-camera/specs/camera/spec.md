## ADDED Requirements

### Requirement: Real-Time Live Preview Frame Rate
The system SHALL render the processed camera preview at a rolling average frame rate of ≥ 30.0 FPS on supported iPhone hardware (iPhone 12 or newer, iOS 17+).

#### Scenario: Dropped Inference Frames
- WHEN the BiSeNet inference queue is actively computing
- THEN the Metal rendering loop SHALL continue rendering at ≥ 30 FPS using the latest available valid mask without blocking on the ML completion.

### Requirement: Deterministic Preview Geometry & Orientation
The camera feed SHALL be configured with portrait orientation (`videoOrientation = .portrait` / `videoRotationAngle = 90`) and front-camera mirroring (`isVideoMirrored = true`). The preview SHALL be aspect-filled and centered without geometric distortion or stretching.

### Requirement: Mask Cache Invalidation
The system SHALL invalidate and clear the active skin mask (`nil` unblurred pass-through) WHEN:
- Inference detects no face or zero skin pixels in frame.
- The face bounding box centroid shifts by > 15% or area shifts by > 20% before the next inference completes.
- The capture session restarts or changes camera position.

### Requirement: Bounded Smoothing Radius
The smoothing filter in the live processor SHALL clamp blur radius strictly to `min(max(baseRadius, 6.0 * scale), 15.0 * scale)` where `scale = frameWidth / 2048.0`.

### Requirement: Camera Session Lifecycle & Permissions
The system SHALL stop the `AVCaptureSession` immediately when the camera view disappears or when the app moves to background (`scenePhase != .active`). If camera authorization is denied, the system SHALL display a non-crashing overlay with a direct action to open iOS Settings.

### Requirement: Still Capture Handoff
Triggering the shutter SHALL capture a high-resolution photo via `AVCapturePhotoOutput` and present it in `EditView` with matching orientation and aspect for review and saving.
