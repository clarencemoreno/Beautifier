# Handoff Document for Qwen — Week 3.5: Semantic Skin Parser

**Project:** Beautifier (`clarencemoreno/Beautifier`)  
**Current Branch:** `main` (commit `ab40e3d`)  
**Tag:** `v0.3.0-week3`  
**Role:** Implementer (Qwen) | Code Reviewer: Antigravity  

---

## 📋 Mission Overview

Week 3 shipped `v0.3.0-week3` using Apple's `VNGeneratePersonSegmentationRequest` with an ellipse fallback. User testing identified a key issue: person segmentation covers the entire person (hair, neck, clothing) rather than skin only, and ellipse fallback on simulator blurs a crude circle.

In **Week 3.5**, you will replace all heuristic and person-segmentation masks with a **true per-pixel semantic face-parsing Core ML model** (BiSeNet trained on CelebAMask-HQ).

The complete OpenSpec change set is ready under:
- [`openspec/changes/add-semantic-skin-parser/proposal.md`](openspec/changes/add-semantic-skin-parser/proposal.md)
- [`openspec/changes/add-semantic-skin-parser/design.md`](openspec/changes/add-semantic-skin-parser/design.md)
- [`openspec/changes/add-semantic-skin-parser/specs/image-editing/spec.md`](openspec/changes/add-semantic-skin-parser/specs/image-editing/spec.md)
- [`openspec/changes/add-semantic-skin-parser/tasks.md`](openspec/changes/add-semantic-skin-parser/tasks.md)

---

## 🚨 Git Branching Rules

Before modifying any files:
```bash
git checkout -b feature/week3.5-semantic-skin-parser
```
All commits must be made on this branch so Antigravity can review the Pull Request.

---

## 🛠️ Step-by-Step Implementation Guide

### Step 1: Model Conversion (Python)
1. Clone `zllrunning/face-parsing.PyTorch`:
   ```bash
   git clone https://github.com/zllrunning/face-parsing.PyTorch.git
   cd face-parsing.PyTorch
   pip install torch torchvision coremltools pillow
   ```
2. Download `79999_iter.pth` from the repo README and place it in the directory.
3. Create `convert_skin_parser.py` (see [`design.md §2`](openspec/changes/add-semantic-skin-parser/design.md)):
   - Run the verification block first: inspect `verify_mask.png`.
   - **Crucial Check:** Face skin MUST be WHITE (`1.0`); eyes, eyebrows, lips, hair, clothing, and background MUST be BLACK (`0.0`).
   - If index 1 is incorrect, iterate `SKIN_INDEX` from 0 to 18 until `verify_mask.png` matches.
4. Export model to `FaceParserSkin.mlpackage`.
5. Drag `FaceParserSkin.mlpackage` into the `Beautifier` target in Xcode.

### Step 2: Swift Core ML Integration
1. Create `Beautifier/Core/ML/SkinParserML.swift`:
   ```swift
   import Vision
   import CoreML

   enum SkinParserML {
       private static let request: VNCoreMLRequest = {
           let config = MLModelConfiguration()
           config.computeUnits = .all // ANE on device, CPU fallback on Simulator
           let model = try! FaceParserSkin(configuration: config).model
           let req = try! VNCoreMLRequest(model: model)
           req.imageCropAndScaleOption = .scaleFill
           return req
       }()

       static func skinMask(for cgImage: CGImage) -> CIImage? {
           let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
           guard (try? handler.perform([request])) != nil,
                 let obs = request.results?.first as? VNPixelBufferObservation
           else { return nil }
           return CIImage(cvPixelBuffer: obs.pixelBuffer)
       }
   }
   ```

### Step 3: Pipeline & Mask Assembly Updates
1. **`SkinMaskBuilder.swift`**:
   - Rewrite to take `skinMask: CIImage`.
   - Scale `skinMask` to match input extent and feather with a 3px Gaussian blur (`CIGaussianBlur`).
   - Delete `rasterizeStructure` and all rectangle exclusion drawing.
2. **`FaceSegmenter.swift`**:
   - Delete `FaceSegmenter.swift`.
3. **`EditViewModel.swift`**:
   - In `load()`: Obtain `aiMask = SkinParserML.skinMask(for: previewCG)` and set `previewMask = SkinMaskBuilder.buildMask(for: previewCI, skinMask: aiMask)`.
   - Restore blur radius clamp: `min(max(faceWidth * 0.04, 4), 15)` (scaled proportionally at full res).
   - Retain `FaceDetector` ONLY for debug bounding box overlay and face width sizing.

### Step 4: Verification & Testing
1. Run the test suite:
   ```bash
   xcodebuild test -project Beautifier.xcodeproj -scheme Beautifier -destination 'platform=iOS Simulator,name=iPhone 17'
   ```
2. Verify:
   - Simulator output matches device (tight ML skin mask, NO circle blob fallback).
   - Eyes, eyebrows, lips, hair, and clothing are sharp at 100% slider intensity.
   - All unit & UI tests pass (**TEST SUCCEEDED**).

### Step 5: Pull Request & Review
1. Push branch:
   ```bash
   git push -u origin feature/week3.5-semantic-skin-parser
   ```
2. Create PR using GitHub CLI:
   ```bash
   gh pr create --title "feat: Add Semantic Face Parsing Skin Mask (Week 3.5)" --body "Replaces heuristic masks with BiSeNet Core ML semantic skin parser." --base main --head feature/week3.5-semantic-skin-parser
   ```
3. Request code review from **Antigravity**.

---

## 🔍 Code Review Criteria (What Antigravity Will Audit)

1. **Mask Precision**: Verification that `FaceParserSkin.mlpackage` correctly isolates skin pixels without leaking into eyes, lips, or background.
2. **Simulator Parity**: Core ML CPU fallback works cleanly on simulator without falling back to geometric shapes.
3. **Blur Radius Clamp**: Restored max 15px radius clamp at 2048px preview scale to eliminate airbrushed blobs.
4. **Code Hygiene**: Removal of `FaceSegmenter.swift`, YCbCr color kernels, and rectangle rasterization code.
5. **Test Integrity**: Full passing test suite (`xcodebuild test`).
