# Beautify — Requirements

**Target Platform:** iOS 17+, iPhone

## Week 1 MVP Requirements

### 1. Functional Requirements

| ID | Requirement | Status |
|----|-------------|--------|
| FR-1 | Import one photo via `PhotosPicker` (no library permission needed to pick). | Verified |
| FR-2 | Display the photo fitted to screen, preserving aspect ratio. | Verified |
| FR-3 | A slider (0–100%) controls smoothing intensity. Preview updates while dragging. | Verified |
| FR-4 | Live preview renders from an image downscaled to max dimension 2048 px. | Verified |
| FR-5 | Long-pressing the preview shows the original; releasing shows the edit. | Verified |
| FR-6 | Save renders the effect at FULL original resolution and writes to Photos (add-only access). | Verified |
| FR-7 | Photos with any EXIF orientation (portrait/landscape/rotated) display and edit correctly. | Verified |
| FR-8 | Save failure or denied permission shows a non-blocking alert. | Verified |

---

## Week 2 Skin-Aware Smoothing Requirements

### 1. Functional Requirements

| ID | Requirement | Status |
|----|-------------|--------|
| FR-W2-1 | YCbCr skin color classification via runtime `CIColorKernel` targeting skin pixels. | Verified |
| FR-W2-2 | Vision landmark detection (`VNDetectFaceLandmarksRequest`) extracting normalized face box & eye/eyebrow/lip exclusions. | Verified |
| FR-W2-3 | Rasterized structure mask blended with color mask and Gaussian feathered (radius 4). | Verified |
| FR-W2-4 | Dynamic blur radius scaled to face size (`faceBox.width * extent.width * 0.04`, clamped 4..15). | Verified |
| FR-W2-5 | Masked skin smoothing via `CIBlendWithMask` keeping facial features and non-skin background sharp. | Verified |
| FR-W2-6 | No-face detected UX state: slider disabled with "No face detected" text hint. | Verified |
| FR-W2-7 | Toolbar toggle button for live grayscale skin mask visualization. | Verified |
| FR-W2-8 | Full-resolution save parity using cached face geometry and full-res rasterized skin mask. | Verified |

---

## Week 3 AI Skin Segmentation Requirements

### 1. Functional Requirements

| ID | Requirement | Status |
|----|-------------|--------|
| FR-W3-1 | Hardware-accelerated AI face segmentation via `VNGeneratePersonSegmentationRequest` running on Apple Neural Engine. | Superseded |
| FR-W3-2 | Pixel-accurate tight face boundary excluding hair, ears, and skin-toned background elements. | Superseded |
| FR-W3-3 | Removal of YCbCr color heuristic kernel (`SkinColorMask.swift` deleted). | Verified |
| FR-W3-4 | Landmark exclusions (eyes, brows, lips) composited over AI face segmentation mask. | Superseded |
| FR-W3-5 | High-resolution full-res parity rendering and save using AI face segmentation. | Superseded |

---

## Week 3.5 Semantic Skin Parser Requirements

### 1. Functional Requirements

| ID | Requirement | Status |
|----|-------------|--------|
| FR-W3.5-1 | Core ML BiSeNet face-parsing model (`FaceParserSkin.mlpackage`) outputting per-pixel skin class probabilities. | Verified |
| FR-W3.5-2 | Natural exclusion by definition: eyes, eyebrows, lips, hair, clothing, and background are excluded in model output. | Verified |
| FR-W3.5-3 | Core ML execution via `SkinParserML.swift` running on Neural Engine (device) and CPU fallback (Simulator). | Verified |
| FR-W3.5-4 | Restored blur radius clamp (`min(max(baseRadius, 6.0 * scale), 15.0 * scale)`) preventing over-smoothed airbrushed blobs. | Verified |
| FR-W3.5-5 | Deletion of legacy `FaceSegmenter.swift` ellipse fallback and rectangle landmark masks. | Verified |

---

## Week 4 Live Camera Pipeline Requirements

### 1. Functional Requirements

| ID | Requirement | Status |
|----|-------------|--------|
| FR-W4-1 | Live front-camera streaming via `CameraService.swift` using `AVCaptureSession` in native portrait-mirrored BGRA format. | Verified |
| FR-W4-2 | Metal-backed live viewport (`MetalView.swift` wrapping `MTKView`) with centered aspect-fill scaling and single `MTLCommandQueue`. | Verified |
| FR-W4-3 | Dedicated serial async inference queue (`LiveProcessor.swift`) preventing render frame drops. | Verified |
| FR-W4-4 | Strict cache invalidation rules (clearing mask on no face or >15% bbox shift). | Verified |
| FR-W4-5 | Bounded smoothing radius cap strictly enforcing `15.0 * scale` limit. | Verified |
| FR-W4-6 | Still photo capture handoff (`AVCapturePhotoOutput`) transitioning to `EditView` for review and saving to Photos. | Verified |
| FR-W4-7 | Camera lifecycle and permission safety: stops capture session on backgrounding, non-crashing permission denied overlay. | Verified |