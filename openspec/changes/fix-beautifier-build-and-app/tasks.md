## 1. Xcode Project & Build Phase Cleanup

- [ ] 1.1 Remove `Info.plist` copy command reference from `PBXResourcesBuildPhase` in `Beautifier.xcodeproj/project.pbxproj`.
- [ ] 1.2 Add `NSPhotoLibraryUsageDescription` and verify `NSCameraUsageDescription` in `Beautifier/Info.plist`.

## 2. Camera & Image Utilities Implementation

- [ ] 2.1 Refactor `CameraView.swift` to handle `UIImagePickerController.isSourceTypeAvailable(.camera)` with photo library fallback for Simulator environments.
- [ ] 2.2 Remove broken `withImageSize` and `compressedJPEGData` UIImage extension code, implementing clean image resizing logic.
- [ ] 2.3 Verify `ContentView.swift` handles camera dismissal, image smoothing, and photo saving error notifications.

## 3. Verification & Execution

- [ ] 3.1 Run `xcodebuild -scheme Beautifier -destination 'platform=iOS Simulator,id=840B14FF-3489-44A3-AF2E-D841C9506AB8'` to ensure clean compilation.
- [ ] 3.2 Run `openspec validate fix-beautifier-build-and-app` to confirm OpenSpec compliance.
