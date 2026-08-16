## Purpose

Defines the restructured image-editing pipeline: import photo → apply skin smoothing
with adjustable intensity → compare → save at full resolution. This is a structural
reorganization of existing, working code — no behavioral changes.

## ADDED Requirements

### Requirement: Restructured Image Pipeline
The system SHALL expose the image-editing pipeline through a restructured codebase
with separated concerns: `Features/Home/` for photo import, `Features/Edit/` for
preview + controls, and `Core/` for rendering primitives.

#### Scenario: Home View Imports Photo
- **WHEN** user taps "Pick Photo" on the home screen
- **THEN** system presents `PhotosPicker`, decodes the selected photo, and navigates to the edit screen with the photo data

#### Scenario: Edit View Renders Preview
- **WHEN** the edit screen receives photo data
- **THEN** system decodes the image, normalizes EXIF orientation, downsamples to max 2048px, and displays the preview

#### Scenario: Smoothing Slider Updates Preview
- **WHEN** user drags the smoothing slider (0–100%)
- **THEN** system applies `SmoothingFilter` asynchronously in a background task and updates the preview in real time

#### Scenario: Long-Press Compares Original
- **WHEN** user long-presses the preview image
- **THEN** system shows the original (unfiltered) image; releasing shows the edited version

#### Scenario: Save Renders Full Resolution
- **WHEN** user taps "Save to Photos"
- **THEN** system decodes the full-resolution original, applies the current smoothing amount, and writes to the Photos library

### Requirement: EditViewModel with Background Task Cancellation
The system SHALL use an `EditViewModel` (`@MainActor`) that manages rendering in
a background `Task`, cancelling any in-flight render when a new slider change arrives
("latest wins" pattern).

#### Scenario: Slider Change Cancels Previous Render
- **WHEN** user rapidly drags the slider
- **THEN** previous render tasks are cancelled; only the latest render result is displayed

#### Scenario: Long-Press Interrupts Render
- **WHEN** user long-presses to compare while a render is in flight
- **THEN** the in-flight render is cancelled and the original is shown immediately

### Requirement: Folder Structure Matches Design.md
The system SHALL organize source files into the following structure:

```
Beautifier/
├── BeautifierApp.swift
├── Features/
│   ├── Home/
│   │   └── HomeView.swift
│   └── Edit/
│       ├── EditView.swift
│       └── EditViewModel.swift
└── Core/
    ├── Rendering/
    │   ├── RenderContext.swift
    │   ├── ImageLoader.swift
    │   └── ImageSaver.swift
    └── Filters/
        └── SmoothingFilter.swift
```

#### Scenario: Project Navigator Shows Correct Structure
- **WHEN** opening the Xcode project
- **THEN** the folder groups `Features/Home`, `Features/Edit`, `Core/Rendering`,
  `Core/Filters` are visible and contain the expected source files
