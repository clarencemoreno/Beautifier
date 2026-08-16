## ADDED Requirements

### Requirement: Real-Time Preview
The system SHALL render the processed camera preview at ≥30fps on device.

### Requirement: Temporal ML Caching
The system SHALL run semantic skin inference at most once per 4 frames and
reuse the cached mask for intermediate frames.

### Requirement: Correct Preview Geometry
The preview SHALL be upright in portrait and aspect-filled without
stretching; the front feed SHALL be mirrored.

### Requirement: Camera Lifecycle
The system SHALL stop the capture session when the screen disappears or the
app backgrounds; denied authorization SHALL show a non-crashing overlay.

### Requirement: Capture Handoff
The shutter SHALL capture a high-res still and hand it to the existing
editor for saving.
