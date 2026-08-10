# Tasks — Semantic Skin Parser

> Rules unchanged: in order, verify each step, no improvisation.

## §1 Convert the model (laptop, one-time)

- [ ] **1.1** Clone `face-parsing.PyTorch`, install deps, download `79999_iter.pth` per design §2.
- [ ] **1.2** Create `convert_skin_parser.py` exactly as in design §2.
- [ ] **1.3** Run the verification block ONLY (comment out the conversion). Open `verify_mask.png`.
  - **Verify:** face skin white; eyes/brows/lips/hair/background black.
  - If wrong: loop SKIN_INDEX 0..18, save each, pick the correct index, update SKIN_INDEX.
- [ ] **1.4** Run the full script → `FaceParserSkin.mlpackage`.
- [ ] **1.5** Drag the `.mlpackage` into the Xcode project target.
  - **Verify:** Xcode shows a generated `FaceParserSkin` class; project builds.

## §2 Swift integration

- [ ] **2.1** Create `Core/ML/SkinParserML.swift` — exact code design §3.
  - **Verify:** compiles.
- [ ] **2.2** Temporary sanity check: in `EditViewModel.load()`, render `SkinParserML.skinMask(for: previewCG)` (scaled up) as the preview.
  - **Verify:** on SIMULATOR: tight white skin mask, black eyes/lips/hair/background. This is the moment the circle disappears.
- [ ] **2.3** Remove the temporary display code. Commit: `feat: semantic skin parser model integrated`.

## §3 Mask builder rewrite

- [ ] **3.1** Replace `SkinMaskBuilder` with the minimal version (design §4): `buildMask(for:skinMask:)` = scale + 3px feather. Delete `rasterizeStructure` entirely.
- [ ] **3.2** Delete `Core/Face/FaceSegmenter.swift`.
- [ ] **3.3** Update `EditViewModel`:
  - `load()`: `aiMask = SkinParserML.skinMask(for: previewCG)`; `previewMask = aiMask.map { SkinMaskBuilder.buildMask(for: previewCI, skinMask: $0) }`; `noFaceDetected = (previewMask == nil or mask mean ≈ 0)`.
  - Keep `FaceDetector` ONLY for radius sizing + debug overlay.
  - **Verify:** compiles; slider smooths skin only; eyes/lips/beard sharp.
- [ ] **3.4** Apply the radius clamp from design §5 in `performRender()` AND `save()`.
  - **Verify:** at 100% slider, skin is smoothed but NOT a textureless blob.
- [ ] **3.5** Commit: `feat: per-pixel skin mask, delete heuristic masks`.

## §4 Acceptance

- [ ] **4.1** Device + Simulator matrix:
  - [ ] Simulator produces the SAME tight mask as device (no circle!)
  - [ ] eyes, brows, lips, teeth sharp at 100%
  - [ ] beard/hair texture preserved
  - [ ] white t-shirt and beige wall untouched
  - [ ] dark and light skin tones both segmented correctly
  - [ ] no-face photo: slider disabled
- [ ] **4.2** Update `docs/REQUIREMENTS.md` (Week 3.5 section), tick items.
- [ ] **4.3** Tag `v0.3.5-semantic-parser`.
