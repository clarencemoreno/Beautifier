# Tasks — Live Camera (v3)

> In order; verify each; no improvisation. Superseded items removed.

## §0 Housekeeping

- [ ] **0.1** Move shipped changes to `openspec/changes/archive/`
  (incl. `add-semantic-skin-parser` once PR #3 merged); write STATUS.md above.
- [ ] **0.2** Verify build green before starting §1.

## §1 Camera Service

- [ ] **1.1** `Core/Camera/CameraService.swift` per earlier draft PLUS:
  - `start()` checks `AVCaptureDevice.authorizationStatus(for: .video)`;
    requests if `.notDetermined`; exposes `@Published var isAuthorized`.
  - **Verify:** compiles.
- [ ] **1.2** `stop()` wired to `onDisappear` AND `scenePhase` background.
  - **Verify:** camera LED off when leaving screen / backgrounding.

## §2 Metal Preview (orientation + aspect correct)

- [ ] **2.1** `Features/Camera/MetalView.swift`: Coordinator owns ONE
  `MTLCommandQueue`; renders via `RenderContext.shared`; applies D4 rotation
  and D5 aspect-fill; NO temporary blur, NO second CIContext, NO
  `mtlCommandQueue` hack.
  - **Verify:** live feed upright, fills screen, faces not stretched.
- [ ] **2.2** `CameraView.swift` with slider + shutter; denied-auth overlay
  when `!camera.isAuthorized`.
- [ ] **2.3** `BeautifierApp.swift` root = `CameraView`; DELETE the PR #3
  `demoImageData` launch-into-EditView hack.
  - **Verify:** app opens to live camera.

## §3 Live Processor

- [ ] **3.1** `Core/Camera/LiveProcessor.swift` per D2/D6.
  - **Verify:** compiles.
- [ ] **3.2** Wire buffer → LiveProcessor → MetalView.
  - **Verify on device:** skin-only smoothing live; eyes/lips sharp;
    ≥30fps; mask refresh invisible.

## §4 Capture

- [ ] **4.1** `AVCapturePhotoOutput` + `capturePhoto()`; shutter wired.
- [ ] **4.2** Captured `Data` → `EditView(originalData:)`.
  - **Verify:** captured still opens in editor and saves correctly.

## §5 Cleanup & Docs

- [ ] **5.1** If unreferenced after §2.3: delete `HomeView.swift` and any
  picker-only tests. **Verify:** build + tests green.
- [ ] **5.2** Append "Week 4" section to `reqs.md`; tick acceptance:
  live ≥30fps on device; upright preview; denied-auth overlay; LED off on exit.
- [ ] **5.3** Tag `v0.4.0-live-camera`.
