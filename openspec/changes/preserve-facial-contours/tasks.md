## Tasks: Edge-Preserving Skin Smoothing & Facial Contour Preservation

- [ ] **1. Upgrade `SmoothingFilter.swift` to Edge-Preserving Filter**
  - [ ] **1.1** Implement frequency separation / guided detail preservation in `Core/Filters/SmoothingFilter.swift`.
  - [ ] **1.2** Add high-frequency edge restoration parameter to maintain contour sharpness during dissolve.

- [ ] **2. Integrate Contour Protection in `SkinMaskBuilder.swift`**
  - [ ] **2.1** Compute luminance edge gradient map (`CIEdges` / Sobel intensity gradient) from source image.
  - [ ] **2.2** Modulate semantic skin mask with inverted edge gradient to suppress smoothing along jawline, nose contours, and eye sockets.

- [ ] **3. Unit Tests & Verification**
  - [ ] **3.1** Add unit test in `BeautifierTests.swift` measuring edge gradient retention along facial contours with high smoothing.
  - [ ] **3.2** Verify that overall skin pore variance decreases while facial line contrast remains sharp.
  - [ ] **3.3** Verify 60fps real-time camera rendering performance on device/simulator.
