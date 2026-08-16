# Design — Core Beautifier MVP (Restructured)

## 1. Context & Constraints

- Solo developer, 1 week, learning while building.
- The Week 1 pipeline (FR-1 through FR-8) is already functional in `ContentView.swift`
  and `ImageProcessing.swift`. This change restructures without changing behavior.
- Must run in real time on GPU; must not crash on 48 MP inputs.
- Architecture must absorb Week 2 (skin mask + tone filters) without rework.

## 2. Goals / Non-Goals

**Goals:** Restructure existing code to match design.md folder layout.
Implement `EditViewModel` with background task cancellation (D6).
No behavior changes.

**Non-goals:** New features, ML models, masking, camera, presets, stretch goal (FR-9).

## 3. Architecture (target state)

```
Beautifier/
├── BeautifierApp.swift          // @main, launches HomeView
├── Features/
│   ├── Home/
│   │   └── HomeView.swift       // PhotosPicker entry point
│   └── Edit/
│       ├── EditView.swift       // preview + controls
│       └── EditViewModel.swift  // state + render orchestration
└── Core/
    ├── Rendering/
    │   ├── RenderContext.swift  // CIContext singleton (existing, unchanged)
    │   └── ImageLoader.swift    // decode, normalize, downsample (extracted)
    │   └── ImageSaver.swift     // add-only save (renamed from PhotoSaver)
    ├── Filters/
    │   └── SmoothingFilter.swift // blur + blend (extracted)
    └── Face/
        └── FaceDetector.swift   // stretch only (not in this change)
```

Data flow: `Data → UIImage (normalized) → CIImage (downsampled preview)
→ filter chain → CIContext.createCGImage → UIImage → SwiftUI Image`.
The view model stores the ORIGINAL `Data` (small) + the preview `CIImage`;
full-res decoding happens only at save time, then is released.

## 4. Key Decisions

### D1 — One shared Metal-backed CIContext
(Already implemented in `RenderContext.swift`. No change.)

### D2 — Normalize EXIF orientation at decode time
(Already implemented in `ImageProcessing.normalizedOrientation()`.
Extracted into `ImageLoader.normalizedImage(from:)`.)

### D3 — Downsample for preview, full-res only on save (memory safety)
(Already implemented via `CGImageSourceCreateThumbnailAtIndex`.
Extracted into `ImageLoader.downsampledPreviewCIImage(from:maxDimension:)`.)

### D4 — Smoothing = blur blended with original by intensity
(Already implemented in `ImageProcessing.applySmoothing()`.
Extracted into `SmoothingFilter.apply(to:amount:)`.)

### D5 — PhotosPicker for import, add-only for save
(Already implemented. `ImageSaver` is a rename of `PhotoSaver`.)

### D6 — Rendering off the main actor (NEW)
Preview renders run in a background `Task`; the result is published back to
the UI. Slider changes cancel any in-flight render task (latest wins).

```swift
// EditViewModel.swift
@MainActor
final class EditViewModel: ObservableObject {
    @Published var originalData: Data?
    @Published var previewCI: CIImage?
    @Published var previewImage: UIImage?
    @Published var amount: Float = 0.5
    @Published var showingOriginal = false
    @Published var alert: AlertState?

    private var renderTask: Task<Void, Never>?

    func renderPreview() {
        renderTask?.cancel()
        renderTask = Task {
            await performRender()
        }
    }

    private func performRender() async {
        guard let previewCI else { return }
        let output = amount <= 0 || showingOriginal
            ? previewCI
            : try SmoothingFilter.apply(to: previewCI, amount: amount)
        guard let cgImage = RenderContext.shared.createCGImage(output, from: output.extent) else { return }
        await MainActor.run {
            self.previewImage = UIImage(cgImage: cgImage)
        }
    }
}
```

## 5. Week 2 seams (why this shape)

- Filters are pure functions `CIImage → CIImage` → Week 2 chains a
  `CIBlendWithMask` after `SmoothingFilter` with no API change.
- `Core/Face/` exists as an empty group → Vision landmark work drops in.
- Preview/full-res split is already solved → live camera reuses it.

## 6. Risks / Trade-offs

| Risk | Response |
|------|----------|
| Refactoring introduces regressions | Preserve all existing behavior; verify FR-1 through FR-8 after restructuring. |
| `EditViewModel` adds indirection | Minimal — it replaces the `@State` properties that were already in `ContentView`. |
| File count increases | Expected — this is the design.md structure. Easier to find code. |
