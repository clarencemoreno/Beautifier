---
schema: spec-driven
created: 2026-08-09
---

# Change: Restructure Core Beautifier MVP

## Why

The Week 1 MVP pipeline (import → smooth → compare → save) is fully functional but
monolithic: all UI state and rendering logic lives in a single `ContentView.swift`
file, and all image processing is bundled into `ImageProcessing.swift`. This makes
the codebase hard to maintain, test, and extend.

The design.md for the core MVP specifies a clean architecture with separated concerns:
`Features/Home/`, `Features/Edit/`, `Core/Rendering/`, `Core/Filters/`, and
`Core/Face/`. The current code does not match this structure.

This change restructures the existing, working code to match the design.md architecture
without adding new features, changing behavior, or introducing new dependencies.

## What Changes

- **NEW** `Features/Home/HomeView.swift` — `PhotosPicker` entry point, navigates to EditView.
- **NEW** `Features/Edit/EditView.swift` — Preview display, smoothing slider, save button.
- **NEW** `Features/Edit/EditViewModel.swift` — `@MainActor` view model with `@Published` state,
  background `Task` for rendering with cancellation ("latest wins").
- **NEW** `Core/Rendering/ImageLoader.swift` — Decode data → UIImage, normalize EXIF, downsample
  to 2048px preview (extracted from `ImageProcessing.swift`).
- **NEW** `Core/Filters/SmoothingFilter.swift` — Gaussian blur (radius 8) blended with original
  via `CIDissolveTransition` (extracted from `ImageProcessing.swift`).
- **RENAMED** `PhotoSaver.swift` → `Core/Rendering/ImageSaver.swift` — Add-only Photos save.
- **REMOVED** `ContentView.swift` — Replaced by `HomeView` + `EditView`.
- **REMOVED** `ImageProcessing.swift` — Replaced by `ImageLoader` + `SmoothingFilter`.
- **MODIFIED** `BeautifierApp.swift` — Launches `HomeView` instead of `ContentView`.

## Impact

- **Affected specs:** `image-editing` (new capability describing the restructured pipeline)
- **Affected code:** `BeautifierApp.swift`, `ContentView.swift` (removed),
  `ImageProcessing.swift` (removed), `PhotoSaver.swift` (renamed/moved), plus 5 new files.
- **Permissions:** No changes — `NSPhotoLibraryAddUsageDescription` already in `Info.plist`.
- **Dependencies:** None beyond system frameworks (SwiftUI, PhotosUI, CoreImage, Metal, Photos).
- **Behavior:** No user-visible behavior changes. The pipeline (import → smooth → compare → save)
  works identically after restructuring.
