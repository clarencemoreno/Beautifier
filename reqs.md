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
| FR-W3-1 | Hardware-accelerated AI face segmentation via `VNGeneratePersonSegmentationRequest` running on Apple Neural Engine. | Verified |
| FR-W3-2 | Pixel-accurate tight face boundary excluding hair, ears, and skin-toned background elements. | Verified |
| FR-W3-3 | Removal of YCbCr color heuristic kernel (`SkinColorMask.swift` deleted). | Verified |
| FR-W3-4 | Landmark exclusions (eyes, brows, lips) composited over AI face segmentation mask. | Verified |
| FR-W3-5 | High-resolution full-res parity rendering and save using AI face segmentation. | Verified |