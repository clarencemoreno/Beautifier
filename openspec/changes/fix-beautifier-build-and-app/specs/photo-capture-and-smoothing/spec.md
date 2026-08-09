## Purpose

Enables users to take a photo using the device camera (or simulator mock image picker), apply CoreImage skin-smoothing filters, and save the result to the iOS Photos library.

## ADDED Requirements

### Requirement: Camera Capture with Environment Compatibility
The system SHALL present an interactive camera interface on supported hardware and provide a mock/sample image fallback when running in environment environments (such as iOS Simulator) where camera hardware is absent.

#### Scenario: Hardware Camera Launch
- **WHEN** user taps "Take Photo" on a physical iOS device with camera access
- **THEN** system presents the camera viewfinder for photo capture

#### Scenario: Simulator Camera Fallback
- **WHEN** user taps "Take Photo" inside the iOS Simulator
- **THEN** system presents a mock image selector or generates a sample image without crashing

### Requirement: Skin Smoothing Image Processing
The system SHALL execute CoreImage skin-smoothing algorithms asynchronously off the main thread to prevent UI freezing.

#### Scenario: Smooth Image Processing
- **WHEN** user applies skin smoothing to a selected photo
- **THEN** system generates a smoothed preview image asynchronously and updates the display upon completion

### Requirement: Photo Library Export and Permission Handling
The system SHALL request explicit Photo Library write permissions (`NSPhotoLibraryAddUsageDescription`) and save the output image to the user's Photos library.

#### Scenario: Save Photo to Library
- **WHEN** user taps "Save to Photos" with a processed photo present
- **THEN** system saves the image into the device Photos album and displays a success notification
