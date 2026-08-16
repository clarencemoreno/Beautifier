# Design — Live Camera Pipeline (v3)

## 1. Context

Live 60fps beautification reusing the Week 3.5 semantic pipeline.
Static picker flow is deprecated; camera is the root scene.

## 2. Frame budget & Temporal Caching

SkinParserML ≈ 15–25ms (ANE). Budget is 16ms/frame. Therefore:
refresh ML mask every 4th frame; reuse cached mask between refreshes
(~66ms staleness at 60fps — imperceptible for faces).

## 3. Decisions

### D1 — One context, one queue
Coordinator owns `let commandQueue = device.makeCommandQueue()`.
All rendering uses `RenderContext.shared` (already Metal-backed).
No per-frame allocation of contexts/queues. Delete the
`mtlCommandQueue` extension hack from the Phase-1 sketch.

### D2 — Temporal caching
`LiveProcessor.process(_ image: CIImage) -> CIImage`:
`frameIndex % 4 == 0` → run `SkinParserML.skinMask` (+ `FaceDetector`
for radius sizing) on that frame, store `cachedMask`/`cachedFaceWidth`;
every frame → `SkinSmoothing.apply` with cached values.
Warm-up frames (no mask yet) return the image unmodified.

### D3 — Mirroring
`connection.isVideoMirrored = true` on the video output. Buffers arrive
pre-mirrored; Vision and rendering operate in that same space. No extra flips.

### D4 — Orientation & portrait lock
Sensor buffers are landscape. Lock the app to portrait
(Info.plist `UISupportedInterfaceOrientations` = portrait only) and rotate
each frame once: `CIImage(cvPixelBuffer:).oriented(.right)`
(verify empirically on device; use `.left` if inverted).
The ML refresh frame and every render frame use the SAME oriented image.

### D5 — Aspect-fill preview
scale = max(drawableW/imgW, drawableH/imgH); translate to center;
crop to drawable bounds. Never scale X/Y independently (no stretching).

### D6 — Radius formula (live)
Reuse Week 3.5: `radius = clamp(faceWidth * frameW * 0.05, 6*s, 24*s)`
with `s = frameW / 2048`.

### D7 — Capture handoff
Shutter → `AVCapturePhotoOutput` → `Data` → push existing `EditView`
(prototype editor) for save. No duplicate filter logic.

### D8 — Lifecycle & permissions
`start()`/`stop()` on serial queue; stop on `scenePhase != .active` and
`onDisappear`. Denied camera auth → overlay with Settings link, no crash.

## 4. Risks

| Risk | Response |
|------|----------|
| Simulator fps low (CPU ML) | Acceptance on device only. |
| Thermal throttling | STRETCH: halve refresh rate when thermalState ≥ .serious. |
