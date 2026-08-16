# Change: Add Live Camera Pipeline (Week 4) — v2

> **STATUS: BLOCKED on `add-semantic-skin-parser`.** Do not start until
> v0.3.5 ships. v2 replaces all `FaceSegmenter` references with
> `SkinParserML` (FaceSegmenter is deleted by Week 3.5).

## Why

A static editor is a utility; a live beautifier is a product. This change
streams the camera through the (now-correct) semantic skin pipeline at
30–60fps.

## What Changes

- **NEW** `Core/Camera/CameraService.swift` — AVCaptureSession + video data
  output + photo output.
- **NEW** `Core/Camera/LiveProcessor.swift` — applies `SkinSmoothing` per
  frame; refreshes the `SkinParserML` mask every 4th frame (temporal caching).
- **NEW** `Features/Camera/` — `CameraView`, `MetalPreviewView`,
  `CameraViewModel`.
- **MODIFIED** `HomeView` — "Live Camera" entry point.

## Impact

- Affected specs: `image-editing` (live delta), new `camera` capability.
- Permissions: `NSCameraUsageDescription` already present in Info.plist.
