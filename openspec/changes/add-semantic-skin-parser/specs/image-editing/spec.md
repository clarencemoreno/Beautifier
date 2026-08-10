## MODIFIED Requirements

### Requirement: Per-Pixel Skin Segmentation
The system SHALL determine the smoothing mask using a semantic face-parsing
model whose skin class excludes eyes, eyebrows, lips, hair, clothing, and
background by definition. Rectangle-based exclusions and color heuristics
SHALL NOT be used.

#### Scenario: Beard and hairline
- WHEN the subject has facial hair or hair over the forehead
- THEN hair pixels SHALL remain unsmoothed while adjacent skin is smoothed

#### Scenario: Simulator parity
- WHEN run in the Xcode Simulator
- THEN the mask SHALL be produced by the Core ML model (CPU fallback),
  not by a geometric fallback shape

### Requirement: Bounded Smoothing Radius
The system SHALL clamp the Gaussian radius so that no mask region ever
receives an effective blur exceeding 15px at 2048px preview scale
(scaled proportionally at other resolutions).
