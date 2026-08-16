# Change: Replace Heuristic Masks with Semantic Face Parsing (Week 3.5)

> **STATUS: ACTIVE — next change to implement.**
> **SUPERSEDES:** `add-ml-skin-parser` (v0.3.0-week3, regressed).
> **ON COMPLETION:** tag `v0.3.5-semantic-parser`; move this folder and
> `add-ml-skin-parser` to `openspec/changes/archive/`; update STATUS.md.

## Why

v0.3.0 shipped a regression. `VNGeneratePersonSegmentationRequest` segments
the whole person (hair, shirt, neck), is unavailable on the Simulator (the
ellipse fallback blurs a crude circle), and rectangle landmark exclusions
cannot protect facial features from a large-radius blur. User testing
confirmed the output reads as "one smoothed blob over the face."

The fix is true per-pixel semantic face parsing: a BiSeNet model trained on
CelebAMask-HQ that outputs class labels (skin, brows, eyes, lips, hair,
background) for every pixel. The skin class IS the mask — features, hair,
and clothing are excluded by definition.

## What Changes

- **NEW** `FaceParserSkin.mlpackage` — pretrained BiSeNet converted via
  coremltools (one-time Python script, NO training).
- **NEW** `Core/ML/SkinParserML.swift` — runs the model via `VNCoreMLRequest`,
  returns a grayscale skin-probability CIImage.
- **REWRITTEN** `SkinMaskBuilder` — mask = ML skin output, scaled + feathered.
  Rectangle exclusions and the color heuristic are deleted.
- **DELETED** `FaceSegmenter.swift` (person segmentation + ellipse fallback).
- **FIXED** blur radius clamp restored (4–15px at 2048px preview, scaled
  proportionally at full res).

## Impact

- **Affected specs:** `image-editing` (delta below)
- **Affected code:** `Core/ML` (new), `Core/Filters`, `Features/Edit`
- **Works on Simulator:** Core ML runs on CPU when ANE is unavailable.
