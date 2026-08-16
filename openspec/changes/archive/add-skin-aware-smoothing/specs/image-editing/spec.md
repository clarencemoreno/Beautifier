## ADDED Requirements

### Requirement: Skin-Only Smoothing
The system SHALL apply smoothing only to pixels classified as skin AND inside
a detected face region.

#### Scenario: Skin-colored background wall
- WHEN a photo contains a beige wall behind the subject
- AND the user sets smoothing above 0%
- THEN the wall SHALL remain pixel-identical to the original

### Requirement: Facial Feature Exclusion
The system SHALL NOT smooth eyes, eyebrows, or lips.

#### Scenario: Eyes retain sharpness
- WHEN smoothing is set to 100%
- THEN eye, eyebrow, and lip regions SHALL match the original within
  negligible blur (< 1px effective radius)

### Requirement: Feathered Mask Edges
The system SHALL blend masked smoothing such that no visible boundary exists
between smoothed and unsmoothed regions at 100% zoom-out.

### Requirement: Face-Relative Intensity
The system SHALL scale smoothing radius with detected face size, clamped to
4–15 px at preview resolution.

#### Scenario: Close-up face vs distant face
- GIVEN two photos, one face filling the frame and one face at 20% width
- WHEN the same slider value is applied
- THEN the close-up SHALL receive a proportionally larger radius

### Requirement: No-Face Behavior
WHEN no face is detected, the system SHALL disable the smoothing slider and
display a "No face detected" hint; the preview SHALL equal the original.

### Requirement: Full-Resolution Mask Parity
The system SHALL produce the saved full-resolution image using the same mask
geometry rasterized at full resolution (not an upscaled preview mask).
