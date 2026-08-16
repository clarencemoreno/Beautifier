# Change: Add Live Camera Pipeline (Week 4)

## Why

A static photo editor is a utility; a live beautifier is a product. Users expect to see the skin smoothing effect in real-time before they snap the photo. This change adapts our existing GPU/ML pipeline to process a live `CMSampleBuffer` stream from the camera at 60fps, replacing the static photo picker as the primary app entry point.

## What Changes

- **NEW** `Core/Camera/CameraService.swift` — wraps `AVCaptureSession` to deliver live video frames.
- **NEW** `Core/Camera/LiveProcessor.swift` — applies the `SkinSmoothing` pipeline to live frames. Implements temporal mask caching (running the BiSeNet ML model every 4th frame) to maintain 60fps.
- **NEW** `Features/Camera/` — `CameraView` (SwiftUI), `MetalView` (MTKView wrapper).
- **MODIFIED** `BeautifierApp.swift` — launches directly into `CameraView`.

## Impact

- **Affected specs:** New `camera` capability.
- **Dependencies:** AVFoundation, MetalKit.
