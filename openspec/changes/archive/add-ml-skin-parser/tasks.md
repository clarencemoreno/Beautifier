# Tasks — AI Skin Segmentation (Week 3)

> **Rules:** Follow design.md exactly. Delete `SkinColorMask.swift` at the end.

## §1 Face Segmenter Wrapper

- [x] **1.1** Create `Core/Face/FaceSegmenter.swift` with `VNDetectFaceSegmentationRequest` wrapper.
- [x] **1.2** Verify segmentation output converting `VNPixelBufferObservation` to `CIImage`.

## §2 Update SkinMaskBuilder

- [x] **2.1** Update `SkinMaskBuilder.rasterizeStructure` in `Core/Filters/SkinMaskBuilder.swift`.
- [x] **2.2** Update `SkinMaskBuilder.buildMask` to accept the AI mask `faceMask: CIImage`.
- [x] **2.3** Delete `Core/Filters/SkinColorMask.swift` from the project.

## §3 Pipeline Integration

- [x] **3.1** Update `EditViewModel` with `faceSegmentationMask: CIImage?`.
- [x] **3.2** Update `renderPreview()` and `save()` to pass `faceSegmentationMask` to `SkinMaskBuilder.buildMask`.

## §4 Week 3 Acceptance & Verification

- [x] **4.1** Execute unit & UI test suite on iOS 17 Simulator.
- [x] **4.2** Tag release `v0.3.0-week3`.
