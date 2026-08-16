## ADDED Requirements

### Requirement: Tight Face Boundary
The system SHALL apply smoothing only within the pixel-accurate boundary of
the detected face, excluding hair, background, and ears.

#### Scenario: Complex background
- WHEN a photo contains a skin-colored wall or object behind the subject
- AND the subject has loose hair over the background
- THEN the background and hair SHALL remain pixel-identical to the original
- AND only the tight face skin SHALL be smoothed

### Requirement: Hardware-Accelerated Segmentation
The system SHALL use hardware-accelerated AI segmentation (Neural Engine)
rather than CPU-bound color heuristics to determine the face boundary.
