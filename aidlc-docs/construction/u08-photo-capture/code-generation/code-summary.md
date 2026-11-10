# Code Summary — Bolt 7 (Photo Capture, U08)

Inputs: U08 functional design (`business-rules.md`, `domain-entities.md`, `frontend-components.md`), `bolt-plan.md` (Bolt 7), `unit-of-work.md` (U08), `requirements.md` (FR-4.1–4.4, FR-6.6, FR-7.5, Open Question 3), `platform-verification.md` (V4, V12), `stories.md` (US-07, US-11), `components.md`, `component-methods.md`, `decisions.md` (ADR-006, ADR-007), mockups and interaction spec; Apple documentation for `ObjectCaptureSession`, `ObjectCaptureView`, `PhotogrammetrySession` (JSON documentation read 2026-11-11).

## What Was Built

| Area | Files | Notes |
|---|---|---|
| Core | `Packages/ScanLabCore/Sources/ScanLabCore/Capture/Photo/` | `PhotoCapturing` port, `PhotoDetailLevel`, `BuildStage`, `PhotoBuildEvent`, `RawCaptureFolders`; `PhotoCaptureError`; `PhotoCaptureFlow` state machine; `PhotoBuildText`; `RawCaptureFiles`; `CameraPositionsFile`; `BackgroundBuildObserver`; `PhotoModelImport` (OBJ → weld → z-up) |
| Core (shared, additive) | `Library/ScanStoring.swift`, `Library/ScanLibrary.swift` | Port gains `attachRawCapture`, `removeRawCapture`, `rawCaptureFolder` with default answers; `MemoryScanStore` implements them; library gains `keepRawCapture`, `discardRawCapture`, `rawCaptureFolder` |
| Core tests | 5 new files | 269 tests in 39 suites; Core line coverage 99.0% (CI run 42911050949) |
| Adapter | `App/Sources/Capture/Photo/ObjectCapturePhotoCapture.swift` | Support and camera permission; `PhotogrammetrySession` with the capture's checkpoint, `.modelFile` to a folder (OBJ) at `.reduced` plus `.poses`; USDZ + Model I/O fallback; camera-positions CSV |
| Screen | `PhotoCaptureView.swift`, `PhotoCaptureModel.swift`, `PhotoCaptureModel+Building.swift` | Guided capture with `ObjectCaptureView`, building progress, keep/discard, unfinished capture, background observation |
| Raw export | `RawCaptureExport.swift`; one row in `Screens/ScanDetailView.swift` | Zip by `NSFileCoordinator` `.forUploading`, save chooser |
| Wiring (shared, additive) | `AppEnvironment.swift`, `Library/FileScanStore.swift` | `photoCapture` in the composition root; file store moves the folder into `RawCapture/` |
| Checklist | `docs/checklists/bolt-07-photo-capture.md` | |

Entry point for New scan › Photos: `PhotoCaptureView(environment: environment)`,
presented full screen.

## Deviations From the Design

- `PhotoCapturing` is `detailLevel`, `prepare()`, `build(_:) -> AsyncThrowingStream`;
  there is no `start()/events/finish() -> RawCapture`, because `ObjectCaptureView` needs
  the concrete `ObjectCaptureSession`, so guided capture lives in the App screen model.
- `ScanStoring.rawCaptureURL` became `rawCaptureFolder(for:)` plus `attachRawCapture` and
  `removeRawCapture`; `keepRawCapture(_:keep:)` became `keepRawCapture(_:from:)` and
  `discardRawCapture(_:)`.
- Raw-capture export is a row on Scan detail, not a switch on the Export sheet.
- The `CaptureCoordinator`/`CaptureEvent` shared state machine (U07) is not used; U08 has
  its own `PhotoCaptureFlow`. Unifying them is for U09 if wanted.
- No `project.yml` change was needed (camera purpose text already present).

## Not Verified

- Everything on the phone: Object Capture itself, OBJ output on iOS (the fallback is
  untested too), units and orientation of the model, camera-positions content, keep
  move, zip export, background behaviour. Covered by the checklist.
- Apple forum reports of Object Capture failing on iPhone 17 Pro under iOS 26.4–26.5
  (sensor failure, reconstruction error 4004): could affect the owner's phone.
- The 10-photo minimum is ScanLab's own assumption.
- Whether `ObjectCaptureSession.Error` and `PhotogrammetrySession.Error` cases map as
  intended at run time; compiler warnings in the app build (CI shows the last 40 lines).
- Not run against Bolt 6's New scan screen; the Photos screen is unreachable on this
  branch until the merge.
