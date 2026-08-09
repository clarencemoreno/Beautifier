# Tasks — Core Beautifier MVP (Restructured)

> **Rules for the implementer (human or LLM):**
> 1. Complete tasks strictly in order. Do not skip or reorder.
> 2. Each task has a **Verify** step. Do not start the next task until it passes.
> 3. Follow `design.md` code sketches exactly. Do not refactor, rename, or
>    "improve" anything outside the current task.
> 4. Commit after each completed section (§1, §2, …).

## §1 Project Scaffolding

- [ ] **1.1** Create this exact folder structure (empty groups in Xcode):
  `Features/Home`, `Features/Edit`, `Core/Rendering`, `Core/Filters`, `Core/Face`.
  - **Verify:** folders visible in the project navigator; app still builds.

- [ ] **1.2** Commit: `chore: create restructured folder layout`.

## §2 Extract Core Rendering

- [ ] **2.1** `Core/Rendering/RenderContext.swift` — Copy existing file (no changes).
  - **Verify:** file compiles.

- [ ] **2.2** `Core/Rendering/ImageLoader.swift` — Extract from `ImageProcessing.swift`:
  - `static func normalizedImage(from data: Data) throws -> UIImage`
    (decode + `normalizedOrientation()`)
  - `static func downsampledPreviewCIImage(from data: Data, maxDimension: CGFloat) throws -> CIImage`
    (CGImageSource thumbnail, max 2048px)
  - **Verify:** file compiles.

- [ ] **2.3** `Core/Rendering/ImageSaver.swift` — Rename from `PhotoSaver.swift`:
  - `static func save(_ image: UIImage) async throws`
  - (Keep the async/await `PHPhotoLibrary` implementation — it's already better than
    the design.md's synchronous `UIImageWriteToSavedPhotosAlbum`.)
  - **Verify:** file compiles.

- [ ] **2.4** Commit: `feat: extract rendering core (context, loader, saver)`.

## §3 Extract Smoothing Filter

- [ ] **3.1** `Core/Filters/SmoothingFilter.swift` — Extract from `ImageProcessing.swift`:
  - `static func apply(to ciImage: CIImage, amount: Float) throws -> CIImage`
    (Gaussian blur radius 8, blended with original via `CIDissolveTransition`)
  - **Verify:** file compiles.

- [ ] **3.2** Commit: `feat: extract smoothing filter`.

## §4 Create EditViewModel (D6)

- [ ] **4.1** `Features/Edit/EditViewModel.swift`:
  ```swift
  @MainActor
  final class EditViewModel: ObservableObject {
      @Published var originalData: Data?
      @Published var previewCI: CIImage?
      @Published var previewImage: UIImage?
      @Published var amount: Float = 0.5
      @Published var showingOriginal = false
      @Published var alert: AlertState?

      private var renderTask: Task<Void, Never>?

      func load(data: Data) {
          originalData = data
          do {
              previewCI = try ImageLoader.downsampledPreviewCIImage(
                  from: data, maxDimension: 2048)
              renderPreview()
          } catch {
              alert = AlertState(title: "Error", message: error.localizedDescription)
          }
      }

      func renderPreview() {
          renderTask?.cancel()
          renderTask = Task {
              await performRender()
          }
      }

      private func performRender() async {
          guard let previewCI, !Task.isCancelled else { return }
          let output = showingOriginal || amount <= 0
              ? previewCI
              : try? SmoothingFilter.apply(to: previewCI, amount: amount)
          guard let output, !Task.isCancelled else { return }
          guard let cgImage = RenderContext.shared.createCGImage(output, from: output.extent) else { return }
          await MainActor.run {
              previewImage = UIImage(cgImage: cgImage)
          }
      }

      func save() async {
          guard let data = originalData else { return }
          do {
              let normalizedImage = try ImageLoader.normalizedImage(from: data)
              guard let ciImage = CIImage(image: normalizedImage) else { return }
              let output = try SmoothingFilter.apply(to: ciImage, amount: amount)
              let result = try ImageLoader.renderUIImage(from: output, scale: normalizedImage.scale)
              try await ImageSaver.save(result)
              await MainActor.run {
                  alert = AlertState(title: "Saved", message: "Saved to Photos.")
              }
          } catch {
              await MainActor.run {
                  alert = AlertState(title: "Error", message: error.localizedDescription)
              }
          }
      }
  }
  ```
  - **Verify:** compiles.

- [ ] **4.2** Commit: `feat: create EditViewModel with background task cancellation`.

## §5 Create HomeView (FR-1)

- [ ] **5.1** `Features/Home/HomeView.swift`:
  - `@State var pickerItem: PhotosPickerItem?`
  - `@State var viewModel: EditViewModel` (or pass data via navigation)
  - `PhotosPicker(selection:)` bound to `pickerItem`
  - `.onChange(of: pickerItem)`: load `Data`, navigate to `EditView` with data.
  - **Verify:** picking a photo transitions to the (still empty) EditView.

- [ ] **5.2** Commit: `feat: home screen with photo import (FR-1)`.

## §6 Create EditView (FR-2 … FR-6)

- [ ] **6.1** `Features/Edit/EditView.swift` layout:
  - `EditViewModel` as `@StateObject`.
  - Preview: `GeometryReader` + `Image(viewModel.previewImage)`, `.resizable().scaledToFit()`.
  - Bottom bar: slider (0...1, bound to `viewModel.amount`), Save button.
  - **Verify:** layout renders with the imported photo.

- [ ] **6.2** Wire the slider: `.onChange(of: viewModel.amount)` calls
  `viewModel.renderPreview()`.
  - **Verify:** dragging the slider updates the preview live (NFR-1).

- [ ] **6.3** Implement long-press compare (FR-5):
  `.onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
  viewModel.showingOriginal = pressing; viewModel.renderPreview() }, perform: {})`
  - **Verify:** holding shows the original; releasing shows the edit.

- [ ] **6.4** Wire Save button to `viewModel.save()` async, with in-progress state.
  - **Verify:** saves full-resolution photo (FR-6, FR-8).

- [ ] **6.5** Commit: `feat: edit screen with live smoothing, compare, save`.

## §7 Update App Entry Point

- [ ] **7.1** `BeautifierApp.swift` — Replace `ContentView()` with `HomeView()`.
  - **Verify:** app launches, shows home screen with "Pick Photo" button.

- [ ] **7.2** Commit: `feat: update app entry point to HomeView`.

## §8 Cleanup

- [ ] **8.1** Remove `ContentView.swift` and `ImageProcessing.swift` from the Xcode project.
  - **Verify:** app still builds.

- [ ] **8.2** Remove `CameraView.swift` and `LiveBeautifyCameraView.swift` from the project
  (they are Week 2 non-goals and not wired in).
  - **Verify:** app still builds.

- [ ] **8.3** Commit: `chore: remove obsolete files (ContentView, ImageProcessing, CameraView, LiveBeautifyCameraView)`.

## §9 Week 1 Acceptance

- [ ] **9.1** Run the manual test matrix on a PHYSICAL device:
  - [ ] portrait photo imports, edits, saves correctly
  - [ ] landscape photo imports, edits, saves correctly
  - [ ] photo taken upside-down/rotated imports without rotation glitches
  - [ ] one 40+ MP photo: no crash, slider still responsive (NFR-2)
  - [ ] save with Photos permission denied → error alert, no crash
  - [ ] saved image dimensions == original image dimensions

- [ ] **9.2** Confirm Definition of Done items in `docs/REQUIREMENTS.md §7`;
  tick them there.

- [ ] **9.3** Tag the commit `v0.1.0-week1`.
