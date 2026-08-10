# Change: Add AI Skin Segmentation (Week 3)

## Why

Week 2's skin mask relied on a rectangular `faceBox` and a YCbCr color
heuristic. This caused two visible artifacts:
1. Backgrounds or walls with skin-like colors (beige, pink) were smoothed.
2. Hair, ears, and necks outside the rectangular box were not smoothed.

The fix is to replace the heuristic with a tight, AI-generated segmentation
mask. Apple's Vision framework provides `VNDetectFaceSegmentationRequest`,
which runs a pre-trained Core ML model on the Neural Engine to output a
pixel-accurate mask of the face. By multiplying this tight mask with our
existing landmark exclusions (eyes, brows, lips), we achieve true
"skin-only" smoothing.

## What Changes

- **NEW** `FaceSegmenter.swift` — wraps `VNDetectFaceSegmentationRequest` and
  converts the resulting `VNPixelBufferObservation` (a single-channel mask)
  into a `CIImage`.
- **MODIFIED** `SkinMaskBuilder` — removes the `SkinColorMask` multiplication.
  Instead, it rasterizes the tight `VNDetectFaceSegmentationRequest` mask,
  punches black holes for the `FaceGeometry` exclusions (eyes/lips), and
  feathers the edges.
- **DELETED** `SkinColorMask.swift` — the YCbCr color heuristic is no longer
  needed.

## Impact

- **Affected specs:** `image-editing` (delta: 2 added requirements)
- **Affected code:** `Core/Face` (new segmenter), `Core/Filters` (mask builder
  update), `Features/Edit/EditViewModel` (pipeline update)
- **Dependencies:** none new (Vision framework)
