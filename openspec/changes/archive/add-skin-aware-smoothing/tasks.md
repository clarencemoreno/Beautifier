# Tasks — Skin-Aware Smoothing

> **Rules for the implementer (human or LLM):**
> 1. Complete tasks strictly in order. Each has a **Verify** step — pass it
>    before moving on.
> 2. Follow `design.md` code sketches EXACTLY. No renaming, no refactors
>    beyond what the task says.
> 3. Coordinate rule of the week: Vision and CIImage are BOTH bottom-left
>    origin. Never flip Y inside the mask pipeline. Only flip for SwiftUI display.
> 4. Commit after each section.

## §1 Skin Color Kernel

- [ ] **1.1** Create `Core/Filters/SkinKernels.ci.metal` — filename must end
  in exactly `.ci.metal` — with the exact kernel code from `design.md §D7`.
  - **Verify:** project builds with no errors.

- [ ] **1.2** Create `Core/Filters/SkinColorMask.swift` with the exact code
  from `design.md §D7`.
  - **Verify:** compiles.

- [ ] **1.3** Temporary sanity check: in `EditViewModel.load(data:)`, after
  `previewCI` exists, render `SkinColorMask.apply(to: previewCI)` to a UIImage
  and display it (replace the preview temporarily).
  - **Verify:** face/neck/hands appear WHITE, everything else near-BLACK.
    If the app crashes on bundle load, the `.ci.metal` file is misnamed or
    not in the target membership — fix before continuing.

- [ ] **1.4** Remove the temporary display code from 1.3.
  - **Verify:** app back to Week 1 behavior. Commit: `feat: skin color kernel`.

## §2 Face Geometry from Landmarks

- [ ] **2.1** Create `Core/Face/FaceGeometry.swift` containing the
  `FaceGeometry` struct and `FaceGeometryBuilder` — exact code from
  `design.md §D9`.
  - **Verify:** compiles.

- [ ] **2.2** Extend `Core/Face/FaceDetector.swift` with:
  ```swift
  static func detectGeometry(in cgImage: CGImage) -> FaceGeometry? {
      let request = VNDetectFaceLandmarksRequest()
      let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
      try? handler.perform([request])
      // pick the LARGEST face by bounding-box area
      guard let best = request.results?
          .max(by: { area($0) < area($1) }) else { return nil }
      return FaceGeometryBuilder.build(from: best)
  }
  private static func area(_ f: VNFaceObservation) -> CGFloat {
      f.boundingBox.width * f.boundingBox.height
  }
  ```
  - **Verify:** compiles.

- [ ] **2.3** Debug-verify geometry: temporarily draw the normalized
  `faceBox` (green) and each `exclusions` rect (red) over the preview using
  the Week 1 overlay approach (remember: flip Y for SwiftUI display).
  - **Verify:** green box covers face INCLUDING forehead; red boxes sit on
    both eyes, both eyebrows, and lips — on a portrait AND a landscape photo.
    Wrong positions usually mean an accidental Y-flip; fix before continuing.

- [ ] **2.4** Remove the debug drawing code from 2.3. Commit:
  `feat: face geometry from vision landmarks`.

## §3 Mask Assembly

- [ ] **3.1** Create `Core/Filters/SkinMaskBuilder.swift` with the exact code
  from `design.md §D10`.
  - **Verify:** compiles.

- [ ] **3.2** Temporary sanity check: in `load(data:)`, run detection →
  `SkinMaskBuilder.buildMask(for: previewCI, geometry:)` → display the mask.
  - **Verify:** face skin WHITE; eyes/brows/lips BLACK; background BLACK;
    edges visibly soft (not razor-sharp). If exclusions are filled white,
    check fill-color ordering in `rasterizeStructure`.

- [ ] **3.3** Remove the temporary display code. Commit:
  `feat: skin mask builder`.

## §4 Pipeline Integration

- [ ] **4.1** Refactor `SmoothingFilter.apply(to:amount:)` →
  `apply(to:radius:amount:)` (remove `static let radius`; use the parameter).
  Update the single existing call site.
  - **Verify:** builds; Week 1 behavior unchanged at radius 8.

- [ ] **4.2** Create `Core/Filters/SkinSmoothing.swift` — exact code from
  `design.md §D11`.
  - **Verify:** compiles.

- [ ] **4.3** Update `EditViewModel`:
  - Add `@Published var faceGeometry: FaceGeometry?`,
    `@Published var noFaceDetected = false`,
    `@Published var showMaskDebug = false`, and a private
    `previewMask: CIImage?`.
  - In `load(data:)`, after building `previewCI`: run detection in a
    background `Task` using the normalized UIImage's `cgImage`; store
    `faceGeometry`; build and store `previewMask`; set
    `noFaceDetected = (faceGeometry == nil)`; then call `renderPreview()`.
  - **Verify:** loading a portrait photo sets `faceGeometry` non-nil (print or
    breakpoint to confirm).

- [ ] **4.4** Rewrite `renderPreview()`:
  - If `showMaskDebug` → render `previewMask` (or black image if nil).
  - Else if `faceGeometry != nil` → compute
    `radius = min(max(faceBox.width * previewCI.extent.width * 0.04, 4), 15)`
    and render `SkinSmoothing.apply(to: previewCI, mask: previewMask!,
    radius: radius, amount: amount)`.
  - Else → render `previewCI` unchanged.
  - **Verify:** slider now smooths ONLY the face; eyes stay sharp; background
    unchanged (compare with long-press).

- [ ] **4.5** No-face UX: disable the slider when `noFaceDetected`
  (`.disabled(viewModel.noFaceDetected)`) and show the text
  "No face detected" above the slider.
  - **Verify:** test with a landscape photo containing no people: slider is
    greyed out, hint shows.

- [ ] **4.6** Mask debug toggle: add a small toolbar button toggling
  `showMaskDebug`; on toggle call `renderPreview()`.
  - **Verify:** toggle shows the grayscale mask live.

- [ ] **4.7** Save path parity: in `save()`, after decoding full-res CIImage,
  rasterize `SkinMaskBuilder.buildMask` at FULL-RES size from the cached
  `faceGeometry`, compute radius from full-res face width, and run
  `SkinSmoothing.apply` before saving.
  - **Verify:** saved image has the same targeting as the preview (eyes sharp)
    at full pixel dimensions.

- [ ] **4.8** Commit: `feat: skin-aware smoothing pipeline`.

## §5 Week 2 Acceptance

- [ ] **5.1** Manual test matrix on a PHYSICAL device:
  - [ ] close-up selfie: skin smooth, eyes/brows/lips sharp, no halo at face edge
  - [ ] photo with beige/skin-colored wall: wall untouched
  - [ ] photo with hand on cheek: note behavior (acceptable: partially smoothed)
  - [ ] landscape/rotated photo: mask positions still correct
  - [ ] group photo: only the LARGEST face smoothed (multi-face = Week 2 stretch)
  - [ ] no people: slider disabled + hint
  - [ ] slider at 0%: output pixel-identical to original (long-press compare)
  - [ ] saved full-res image matches preview targeting
  - [ ] slider drag still ≤ 100 ms latency

- [ ] **5.2** Update `docs/REQUIREMENTS.md`: append a "Week 2" section listing
  the six requirements from
  `specs/image-editing/spec.md`; tick each one verified in 5.1.

- [ ] **5.3** Tag the commit `v0.2.0-week2`.

## §6 STRETCH — Multi-Face Support

> Only if §1–§5 finished early.

- [ ] **6.1** Change `detectGeometry` to return `[FaceGeometry]` (all faces,
  not just the largest).
- [ ] **6.2** In `SkinMaskBuilder.rasterizeStructure`, draw ALL face boxes
  white and ALL exclusions black into the same context.
- [ ] **6.3** Radius: computed per face — use the LARGEST face's width for
  Week 2 (note the limitation in a code comment).
  - **Verify:** in a two-person photo, both faces are smoothed with correct
    feature exclusion.
