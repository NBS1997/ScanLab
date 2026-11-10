# Code Summary — Bolt 6 (Sweep Capture, U07)

Inputs: U07 functional design (`business-rules.md`, `domain-entities.md`, `frontend-components.md`), `bolt-plan.md` (Bolt 6 and "Added 2026-11-11"), `requirements.md` (FR-2.1, FR-2.2, FR-3.1–3.3, NFR-6, NFR-9), `component-methods.md`, `decisions.md` (ADR-003, ADR-005, ADR-011), `interaction-spec.md`, `mockups.md`.

## What Was Built

| Area | Files | Notes |
|---|---|---|
| Core capture | `Packages/ScanLabCore/Sources/ScanLabCore/Capture/` | `CaptureSession` (phases, allowed-step table, `CaptureTransitionError`), `CaptureError` (with `init(wrapping:)`), `SweepCapturing` port, `SweepProgress`, `SweepTracking`, `MeshPart` + `MeshAssembly` (world transform, 0.5 mm weld, invalid / degenerate / crop drops, report), `Transform(columnMajor:)`, `SweepCaptureService` (session rules → port → `convertedFromYUp()` → `ScanLibrary.add(mesh:method: .sweep)`, logging), `CaptureText` |
| Core sensors | `Sensors/DepthColourMap.swift` (changed), `CloseRangeBand.swift`, `DepthQuality.swift` | `DepthColourMap.closeRange(centredOn:halfWidth:)`, `isNarrow`; band with hysteresis and ±2/±5/±10 cm choices; `DepthQualityInput`, `PoorDepthAdvisor` (named first-guess thresholds), `DepthAdvice`, `SteadyValue` |
| Core tests | `CaptureSessionTests`, `MeshAssemblyTests`, `SweepCaptureServiceTests` (fake port + `MemoryScanStore`), `CloseRangeTests`, `DepthQualityTests` | See CI result below |
| Adapter | `App/Sources/Capture/ARKitSweepCapture.swift`, `LiveSweepCapturing.swift` | `ARWorldTrackingConfiguration`, `sceneReconstruction = .mesh`, gravity alignment; checks `supportsSceneReconstruction(.mesh)` and camera permission; `SweepReceiver` keeps `ARMeshAnchor`s on a serial delegate queue, reports progress at most 4×/s, and at Finish copies each anchor's Metal buffers into `MeshPart`s and assembles them on that queue |
| Screens | `App/Sources/Capture/NewScanView.swift`, `CaptureView.swift`, `CaptureModel.swift` | New scan (Sweep live; Photos via hook), full-screen Capture with wireframe, timer, stats, prompt, Finish/Close, all failure states |
| Wiring | `AppEnvironment.swift` (+`sweepCapture`), `LibraryView.swift` (path-based stack, New scan in bottom bar and empty state), `ExploreModel.swift`, `ExploreView.swift` | Explore: Close range chip, band menu, mm legend, "Move closer" / "Move back" badge, VoiceOver announcement, logs |

## Choices

- **AR view: RealityKit `ARView`** with `.showSceneUnderstanding`. SceneKit (and so
  `ARSCNView`) is deprecated as of iOS 26; RealityKit draws the growing mesh itself, so
  no geometry code per update. Explore still uses `ARSCNView` (unchanged this Bolt).
- **Photos hook:** `NewScanView(environment:photoCapture:onScanSaved:)` with
  `photoCapture: (() -> AnyView)?`. Wiring Bolt 7 is a one-line change in
  `LibraryView.swift`: `photoCapture: nil` → `photoCapture: { AnyView(<PhotoScreen>(…)) }`.
  The screen is pushed onto the navigation stack, so its Back button always works.
- **Poor-depth thresholds** (first guesses, `PoorDepthAdvisor`): reliable minimum 20 cm
  (the standard map's near end); poor-and-near 30 cm; poor when ≥ 30% missing or ≥ 50%
  low-confidence; 11 × 11 pixel square; 0.75 s hold.

## Deviations From the Design

- The port has `start`, `finish`, `cancel` only; `pause`/`resume` and guidance events
  belong to U09.
- `SweepStreams.statuses` reuses the live sensor's `SensorStatus` instead of a new type.
- Assembly runs inside the adapter (on its queue) rather than in the service, so the
  port still returns a finished `Mesh`; the logic is Core's `MeshAssembly` and tested.
- No crop box is used yet (the option exists and is tested); the scan contains whatever
  was reconstructed around the subject.
- Close during capture asks only "Discard?" — Keep and build / Keep for later come with
  U09's interruption handling.
- `DepthQualityInput` lives in Core `Sensors/`, not a new folder, to keep Explore files
  in one place.

## Shared Files Touched

`AppEnvironment.swift` (one property, one argument in each factory) and `LibraryView.swift`
(owned this batch). `project.yml` unchanged (new folder is picked up by `App/Sources`).
None of `ScanDetailView`, `ScanLibrary`, `ScanStoring`, `FileScanStore`, `Scan` or
Diagnostics were edited.

## Not Verified

- Everything on the phone (`docs/checklists/bolt-06-sweep-capture.md`): ARKit mesh
  capture, wireframe drawing, buffer copying, upright result, true size, Fusion
  conversion, permission and unsupported paths, tracking prompts, close-range colours on
  the remote, hint thresholds, VoiceOver.
- Whether one shared `ARView` reused across captures behaves well after many captures.
- Time and memory to assemble a large sweep (copied on a background queue; not measured).
