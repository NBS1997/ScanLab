# Code Summary — Bolt 4 (Live Sensor View, U06)

Inputs: U06 functional design (`business-rules.md`, `domain-entities.md`, `frontend-components.md`), `bolt-plan.md` (Bolt 4), `requirements.md` (FR-2.1, FR-2.2, NFR-6, NFR-7), `decisions.md` (ADR-003, ADR-005, ADR-011).

## What Was Built

| Area | Files | Notes |
|---|---|---|
| Core | `Packages/ScanLabCore/Sources/ScanLabCore/Sensors/` | `DepthFrame`, `ConfidenceLevel`, `SensorFrame`, `SensorStatus`, `SensorStreams`, `SensorFeeding` port; `RGBAColour`, `RGBAImage` (quarter-turn rotation); `DepthColourMap` (0.2–5 m, warm to cool, invalid grey, legend stops); `ConfidenceColourMap`; `CentreSampler` (median of central 5 × 5, skips NaN/zero/low confidence); `FrameRateMeter` (1 s window, gaps, late timestamps); `OverlayRenderer`; `ReadoutText` (mm/m, fps, spoken forms) |
| Core tests | 6 new test files | 72 tests in 14 suites overall; Core line coverage 98.9% (CI run 42812684736) |
| Adapter | `App/Sources/Sensors/LiveSensorFeed.swift` | `ARSession` with `ARWorldTrackingConfiguration` and `.sceneDepth`; checks support and camera permission; `FrameReceiver` on a private serial delegate queue copies depth and confidence pixel buffers (row by row, honouring row padding) into `DepthFrame` and lets the `ARFrame` go; two `AsyncStream`s (frames, newest only; statuses, all kept); logs start, first frame, stop summary, frame rate every 10 s, tracking changes, interruptions, failures and permission denial |
| App port | `App/Sources/Sensors/LiveCameraFeeding.swift` | `SensorFeeding` plus `makeCameraView()`; `PreviewSensorFeed` for previews; `RGBAImage.makeCGImage()` |
| Screen | `App/Sources/Screens/ExploreView.swift`, `ExploreModel.swift`, `CameraPreview.swift` | Full-screen camera, depth and confidence overlays, centre ring, distance, fps, legends, four toggles (Edges disabled with reason), starting / permission / unsupported / failed / paused states, controls on the trailing edge when sideways |
| Wiring | `AppEnvironment.swift`, `ScanLabApp.swift`, `LibraryView.swift` | `sensorFeed` in the composition root; `live()` and `preview()` now main-actor; Explore button top trailing |

## How the Picture and Overlays Are Drawn

- **Camera:** an `ARSCNView` sharing the feed's `ARSession`. ARKit draws the camera
  image on the GPU, already rotated and aspect-filled to the view. Chosen over
  converting `capturedImage` (1920 × 1440 YCbCr) to an image every frame, which would
  cost far more per frame and risk NFR-7.
- **Overlays:** the 256 × 192 depth or confidence grid is coloured in Core, rotated in
  Core by the quarter turn matching the interface orientation (portrait: clockwise;
  landscape right: none; landscape left: half), turned into a `CGImage`, and drawn
  aspect-fill in the same full-screen rectangle. The grid has the camera picture's
  4 : 3 shape, so it lines up with ARKit's own aspect-fill.
- **Orientation:** `CameraContainerView` reads the window scene's interface orientation
  on each layout and passes changes to the model.

## Deviations From the Design

- The port does not expose `centreDistance` and `frameRate`; the model derives them
  from frames with Core's `CentreSampler` and `FrameRateMeter`.
- `SensorFrame` carries no camera image: the camera is drawn by the ARKit view, so Core
  holds no image handle at all. The app-side `LiveCameraFeeding` adds the view.
- Smoothed scene depth is not used; raw scene depth gives the sensor's own reading for
  FR-2.2.
- A local `ReadoutText` formatter was written because Core `Units` is not on this
  branch; merge with `Units` once both are on `main`.
- `ScanLabApp` builds its environment in `init()` because `AppEnvironment.live()` is now
  main-actor.
- No `UIRequiredDeviceCapabilities` were added: unsupported phones get a message
  instead, and nothing can block install on the iPhone 17 Pro Max.

## Issues Found and Fixed in CI

1. SwiftLint `legacy_swiftui_aspect_ratio`: `.aspectRatio(contentMode: .fill)` → `.scaledToFill()`.
2. swift-format: closing parenthesis of a multi-line `ContentUnavailableView(...)` on its
   own line.

## Not Verified

- Everything on the phone: camera picture, overlay alignment and orientation, colours,
  centre reading accuracy at 1.00 m, frame rate (NFR-7 ≥ 30 fps with all layers on),
  permission prompt and denial path, interruption handling, session stop on leaving,
  VoiceOver and large text. Covered by `docs/checklists/bolt-04-live-sensor-view.md`.
- Compiler warnings in the app build (CI shows only the last 40 lines); `ARSCNView`
  may report SceneKit deprecation warnings on the iOS 26 SDK.
- Main-thread cost of colouring overlays at 60 fps in a Release build.
