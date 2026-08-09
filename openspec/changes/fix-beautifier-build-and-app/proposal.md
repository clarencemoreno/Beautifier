## Why

The Beautifier iOS project currently fails to compile and cannot be launched in Xcode or iOS Simulator due to duplicate build phase outputs (`Info.plist`), invalid/unhandled UIImage utility extensions, missing core photo library permissions, and incomplete camera presentation flow. This proposal fixes the project configuration and codebase to make the application build cleanly, handle permissions gracefully, and allow end-to-end photo capture and skin smoothing.

## What Changes

- **Fix Build Infrastructure**: Remove duplicate `Info.plist` copy step from `Copy Bundle Resources` phase while keeping `GENERATE_INFOPLIST_FILE = NO` and `INFOPLIST_FILE = Beautifier/Info.plist`.
- **Fix Foundation/UIKit Extensions**: Correct the broken `UIImage.withImageSize` and JPEG compression extensions in `CameraView.swift`.
- **Fix Photo Library Permissions**: Add `NSPhotoLibraryUsageDescription` to `Info.plist` alongside existing camera permissions so saving photos works on iOS without runtime security crashes.
- **Improve Camera & Photo Workflow**: Provide fallbacks for iOS Simulator execution (where hardware camera is unavailable) so developers/testers can run and test beautification features.

## Capabilities

### New Capabilities
- `photo-capture-and-smoothing`: Provides camera capture (with simulator fallback), non-blocking image skin-smoothing filters, and photo library export functionality.

### Modified Capabilities
*None*

## Impact

- `Beautifier.xcodeproj/project.pbxproj`: Build phase clean up.
- `Beautifier/Info.plist`: Privacy permissions updated for iOS runtime.
- `Beautifier/CameraView.swift`: Standardized Swift extensions and simulator fallback support.
- `Beautifier/ContentView.swift`: Enhanced error reporting and robust camera presentation.
