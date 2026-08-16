## Requirements: Edge-Preserving Skin Smoothing & Facial Contour Preservation

### Requirement: Facial Contour & Line Preservation
The skin smoothing filter SHALL preserve high-contrast facial contours (including jawline silhouette, nose bridge/creases, and orbital margins) during smoothing operations.

#### Scenario: High Smoothing Applied to Face
- **GIVEN** a face photo or live camera stream with prominent facial features (jawline, nose contours, eyelids)
- **WHEN** the smoothing slider is set to maximum intensity ($1.0$)
- **THEN** high-contrast edge gradients along the jawline and nose contours SHALL retain $> 60\%$ of total structural edge definition across the frame.
- **AND** micro skin surface variance (skin pore roughness and uneven redness) SHALL be reduced by $> 40\%$.

### Requirement: Real-Time Performance
The edge-preserving filter chain SHALL execute within $\le 4\text{ms}$ on Metal GPU hardware during 60fps live camera preview.

#### Scenario: 60 FPS Camera Preview
- **GIVEN** an active camera session streaming at 60 FPS
- **WHEN** the edge-preserving filter processes live frames in `LiveProcessor`
- **THEN** the measured rolling FPS SHALL maintain $> 55\text{ FPS}$ without frame stuttering.
