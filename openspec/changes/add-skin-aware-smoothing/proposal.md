# Change: Add Skin-Aware Smoothing (Week 2)

## Why

Week 1's smoothing blurs the ENTIRE image — including eyes, eyebrows, lips,
backgrounds, and skin-colored walls. That reads as a cheap blur filter, not a
beautifier. The fix is targeting: detect faces, classify skin pixels, exclude
facial features, and apply smoothing only where it belongs. This is the
difference between "filter" and "retouch" and is the core value proposition
of the app.

## What Changes

- **NEW** `SkinKernels.ci.metal` — GPU kernel classifying skin pixels via
  YCbCr color thresholds.
- **NEW** Vision landmark pipeline: enlarged face box + bounding boxes for
  eyes, eyebrows, lips, converted to a normalized `FaceGeometry`.
- **NEW** `SkinMaskBuilder` — rasterizes face box (white) and feature
  exclusions (black) into a grayscale mask, multiplied with the color mask,
  feathered for invisible edges.
- **MODIFIED** `SmoothingFilter` — gains a `radius` parameter; radius now
  scales with detected face size.
- **NEW** `SkinSmoothing` — blur/dissolve result composited over the original
  via `CIBlendWithMask` using the skin mask.
- **NEW** UX: mask debug overlay toggle; slider disabled with a hint when no
  face is detected.
- **MODIFIED** Save path re-rasterizes the cached normalized geometry at full
  resolution.

## Impact

- **Affected specs:** `image-editing` (delta: 6 added requirements)
- **Affected code:** `Core/Filters` (kernel + masked chain), `Core/Face`
  (landmarks → geometry), `Features/Edit/EditViewModel` (pipeline swap)
- **Dependencies:** none new (CoreImage Metal kernels + Vision, both system)
- **Explicit limitation:** hands touching the face, and same-frame skin outside
  the face box, are handled imperfectly by color heuristics — resolved in
  Week 3 by a Core ML face-parsing model.
