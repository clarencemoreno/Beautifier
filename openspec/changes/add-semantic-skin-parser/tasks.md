# Tasks — Semantic Skin Parser (Week 3.5)

> **Execution Guide for Local LLM (Qwen):**
> 1. Complete phases strictly in chronological order (Phase 1 → Phase 6).
> 2. Execute verification commands after each task. Do NOT proceed to the next task if verification fails.
> 3. Do NOT improvise or add unnecessary dependencies/architectural changes.
> 4. Keep code changes atomic and focused.

---

## Phase 1: Environment & Model Preparation (Laptop/Python)

- [ ] **1.1 Set up model conversion workspace**
  - Clone repository: `git clone https://github.com/zllrunning/face-parsing.PyTorch.git /tmp/face-parsing`
  - Install dependencies: `pip install torch torchvision coremltools pillow`
  - Download checkpoint `79999_iter.pth` into `/tmp/face-parsing/`
  - **Validation Command:** `test -f /tmp/face-parsing/79999_iter.pth && echo "CHECKPOINT_OK"`

- [ ] **1.2 Create and run the visual verification script**
  - Create `/tmp/face-parsing/convert_skin_parser.py` with `SKIN_INDEX = 1` and verification pass (see `design.md §2`).
  - Copy `Beautifier/test_face.jpg` to `/tmp/face-parsing/test_face.jpg`.
  - Run: `python /tmp/face-parsing/convert_skin_parser.py`
  - **Validation Gate:** Inspect `/tmp/face-parsing/verify_mask.png`.
    - PASS criteria: Facial skin is pure WHITE (`1.0`); eyes, eyebrows, lips, hair, clothing, and background are pure BLACK (`0.0`).
    - If incorrect: iterate `SKIN_INDEX` from 0 to 18 until `verify_mask.png` matches.

- [ ] **1.3 Convert and export Core ML package**
  - Run full `coremltools` export to produce `FaceParserSkin.mlpackage`.
  - Copy `FaceParserSkin.mlpackage` into `Beautifier/Core/ML/FaceParserSkin.mlpackage`.
  - Add `FaceParserSkin.mlpackage` to Xcode project target `Beautifier`.
  - **Validation Command:** `xcodebuild -project Beautifier.xcodeproj -scheme Beautifier -destination 'platform=iOS Simulator,name=iPhone 17' clean build`
  - **Pass Criteria:** `** BUILD SUCCEEDED **` and generated `FaceParserSkin` class is available.

---

## Phase 2: Core ML Swift Wrapper (`SkinParserML`)

- [ ] **2.1 Implement `SkinParserML.swift`**
  - File: `Beautifier/Core/ML/SkinParserML.swift`
  - Implement static `VNCoreMLRequest` with `.scaleFill` crop/scale and `MLModelConfiguration.computeUnits = .all`.
  - Expose `static func skinMask(for cgImage: CGImage) -> CIImage?`.
  - **Validation Command:** `xcodebuild -project Beautifier.xcodeproj -scheme Beautifier -destination 'platform=iOS Simulator,name=iPhone 17' build-for-testing`

- [ ] **2.2 Add unit test for `SkinParserML`**
  - Add test `testSkinParserMLGeneratesMaskForFaceImage()` in `BeautifierTests/BeautifierTests.swift`.
  - Load `Beautifier/test_face.jpg`, pass to `SkinParserML.skinMask(for:)`.
  - **Validation Command:** `xcodebuild test -project Beautifier.xcodeproj -scheme Beautifier -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BeautifierTests/BeautifierPipelineTests/testSkinParserMLGeneratesMaskForFaceImage`
  - **Pass Criteria:** Mask is non-nil and `** TEST SUCCEEDED **`.

---

## Phase 3: Pipeline Refactoring & Dead Code Removal

- [ ] **3.1 Rewrite `SkinMaskBuilder.swift`**
  - File: `Beautifier/Core/Filters/SkinMaskBuilder.swift`
  - Replace contents with minimal pipeline: scale 512×512 `skinMask` to source `image.extent`, apply 3px `CIGaussianBlur` feathering, crop to `image.extent`.
  - Remove `rasterizeStructure`, landmark rectangle drawing, and YCbCr thresholds.
  - **Validation Command:** `xcodebuild -project Beautifier.xcodeproj -scheme Beautifier -destination 'platform=iOS Simulator,name=iPhone 17' build-for-testing`

- [ ] **3.2 Delete deprecated `FaceSegmenter.swift`**
  - Delete file: `Beautifier/Core/Face/FaceSegmenter.swift`
  - Remove file reference from `Beautifier.xcodeproj/project.pbxproj`.
  - Remove legacy `FaceSegmenter` tests from `BeautifierTests/BeautifierTests.swift`.
  - **Validation Command:** `xcodebuild -project Beautifier.xcodeproj -scheme Beautifier -destination 'platform=iOS Simulator,name=iPhone 17' build-for-testing`

- [ ] **3.3 Validate updated mask builder tests**
  - Ensure `testSkinMaskBuilderNewPipelineScalesMask` and `testSkinMaskBuilderNewPipelineFeathersMask` pass.
  - **Validation Command:** `xcodebuild test -project Beautifier.xcodeproj -scheme Beautifier -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BeautifierTests/BeautifierPipelineTests/testSkinMaskBuilderNewPipelineScalesMask`

---

## Phase 4: ViewModel & UI Integration

- [ ] **4.1 Update `EditViewModel.swift` load pipeline**
  - File: `Beautifier/Features/Edit/EditViewModel.swift`
  - Replace person segmentation calls in `load()` with `SkinParserML.skinMask(for: previewCG)`.
  - Assemble mask via `SkinMaskBuilder.buildMask(for: previewCI, skinMask: aiMask)`.
  - **Validation:** Compiles cleanly with zero compiler warnings.

- [ ] **4.2 Implement no-face check & radius clamping**
  - In `EditViewModel.swift`, if `SkinParserML.skinMask` is nil or mask mean luminance is 0, set `noFaceDetected = true` and disable smoothing slider.
  - In `performRender()` and `save()`, clamp blur radius:
    `min(max(faceWidth * 0.04, 4.0 * scale), 15.0 * scale)` where `scale = image.extent.width / 2048.0`.
  - Retain `FaceDetector` ONLY for debug bounding box overlay and face width sizing.
  - **Validation Command:** `xcodebuild -project Beautifier.xcodeproj -scheme Beautifier -destination 'platform=iOS Simulator,name=iPhone 17' build`

---

## Phase 5: Automated Test Suite & Validation Matrix

- [ ] **5.1 Execute full unit test suite**
  - **Validation Command:** `xcodebuild test -project Beautifier.xcodeproj -scheme Beautifier -destination 'platform=iOS Simulator,name=iPhone 17'`
  - **Pass Criteria:** `** TEST SUCCEEDED **` with 0 failures.

- [ ] **5.2 Acceptance Verification Matrix**
  - [ ] Simulator produces semantic skin mask (NO circle blob fallback).
  - [ ] Eyes, eyebrows, lips, and teeth remain sharp at 100% slider intensity.
  - [ ] Hair, beard texture, and clothing are untouched by blur filter.
  - [ ] Solid/non-face images correctly disable slider (`noFaceDetected = true`).
  - [ ] Save output matches edit preview quality.

---

## Phase 6: Documentation & Handoff

- [ ] **6.1 Update requirements and status**
  - Append Week 3.5 section to `reqs.md` and check off acceptance items.
  - Update `openspec/STATUS.md` reflecting Week 3.5 completion.
- [ ] **6.2 Commit and tag**
  - Commit message: `feat: semantic skin parser model integrated (Week 3.5)`
  - Create tag: `git tag v0.3.5-semantic-parser`
