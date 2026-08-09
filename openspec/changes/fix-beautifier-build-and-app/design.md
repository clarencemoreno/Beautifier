## Context

The `Beautifier` iOS project is configured with modern Xcode settings (`GENERATE_INFOPLIST_FILE = NO`), but `Beautifier/Info.plist` is explicitly listed under the `Copy Bundle Resources` phase in `project.pbxproj`, leading to `ProcessInfoPlistFile` duplicate output errors (`code 65`). In addition, `CameraView.swift` contains invalid Swift syntax in `UIImage` extensions (`withImageSize` and closure returning functions), lacks `NSPhotoLibraryUsageDescription`, and crashes on iOS Simulator when trying to initialize `UIImagePickerController` with `.camera` source.

## Goals / Non-Goals

**Goals:**
- Fix Xcode build failure by cleaning `project.pbxproj` build phases.
- Fix broken Swift extension methods in `CameraView.swift`.
- Add required privacy keys in `Info.plist` (`NSPhotoLibraryAddUsageDescription`, `NSPhotoLibraryUsageDescription`).
- Add simulator guard and fallback in `CameraView` so the app runs smoothly in Xcode Simulator.

**Non-Goals:**
- Replacing CoreImage filters with third-party metal filter shaders.
- Changing target bundle identifier or minimum deployment target.

## Decisions

1. **xcodeproj Build Phase Cleanup**:
   - *Choice*: Remove `Info.plist` reference from `PBXResourcesBuildPhase` in `project.pbxproj`.
   - *Rationale*: `INFOPLIST_FILE` build setting handles Info.plist compilation automatically; including it in resources creates duplicate output targets.

2. **Camera Availability & Simulator Fallback**:
   - *Choice*: Check `UIImagePickerController.isSourceTypeAvailable(.camera)` before instantiating `.camera` picker. If unavailable (e.g., in iOS Simulator), present photo library picker (`.photoLibrary`) or trigger mock photo callback.
   - *Rationale*: Prevents `UIImagePickerController` runtime crashes in iOS Simulator during testing.

3. **Swift UIImage Extension Simplification**:
   - *Choice*: Replace invalid closure-returning `withImageSize` extension with clean `resized(to:)` method.
   - *Rationale*: Eliminates syntax compile errors and avoids memory leak risk during image buffer creation.

## Risks / Trade-offs

- *[Risk] Photo Library Access on Simulator* → *Mitigation*: Ensure both `NSPhotoLibraryUsageDescription` and `NSPhotoLibraryAddUsageDescription` exist in `Info.plist`.
