# Code Summary — Bolt 8 (Accuracy Stage 1, U10)

Inputs: U10 functional design (`business-rules.md`, `domain-entities.md`, `frontend-components.md`), `bolt-plan.md` (Bolt 8), `unit-of-work.md` (U10, U11), `requirements.md` (FR-8.6, FR-9.1–9.4, FR-9.6, FR-9.9), `stories.md` (US-12, US-13), `component-methods.md`, `services.md`, `decisions.md` (ADR-003, ADR-007, ADR-009, ADR-010, ADR-011), `mockups.md`, `mockups.html`, `interaction-spec.md`, `accessibility-checklist.md`, `reference-object/output/`.

## What Was Built

| Area | Files | Notes |
|---|---|---|
| Core | `Packages/ScanLabCore/Sources/ScanLabCore/Accuracy/` (15 files) | Reference model (feature table, binary STL reader, caliper sheet and validation); `SurfaceIndex` (box tree, nearest point on triangles); `SurfaceSampler`; `ScanIsolation`; `Alignment` (36 guesses → trimmed point-to-plane ICP); `Deviation`; report model, reliability rule, verdict; `AccuracyPipeline`; `LinearAlgebra` (Jacobi, Gaussian elimination, Rodrigues). |
| Core (shared, additive) | `Library/ScanStoring.swift`, `Library/ScanLibrary.swift` | Port gains `reportData(for:)`, `replaceReport(_:for:)` (fallbacks in `Accuracy/ReportStoring.swift`); `MemoryScanStore` keeps reports; library gains `attachReport(_:to:)` and `reportData(for:)`. |
| Core tests | 9 new test files | 271 tests in 38 suites, whole suite 12.8 s; Core line coverage 98.9% (CI run 42910890715). The FR-9.9 proof is `AlignmentTests` (0.2 mm offset, 0.25 mm noise, arbitrary pose, background, the real STL) and `DeviationTests` (per-class errors). |
| App | `App/Sources/Accuracy/` (7 files) | `AccuracyService`, `BundledReference`, `CaliperStore`, Accuracy and Reference object screens and models. |
| App (shared, additive) | `AppEnvironment.swift`, `Library/FileScanStore.swift`, `Library/ScanDetailModel.swift`, `Screens/ScanDetailView.swift`, `project.yml` | `reference`, `calipers`, `accuracy`; `accuracy-report.json`; Mark/Unmark in •••, Check accuracy enabled for reference scans, report tick; STL and feature table bundled as resources. |
| Checklist | `docs/checklists/bolt-08-accuracy-surface.md` | |

## Synthetic Accuracy Achieved (in the build)

- Pose recovered to well under 0.05 mm at every point (rotation error under 1e-4 rad)
  from a 35° turn and 37 cm move, for the test object and for the real reference STL.
- 0.2 mm built-in offset reported as 0.2 mm (mean and RMS, overall and in each size
  class) within 0.05 mm; 0.25 mm noise reported as 0.25 mm RMS, mean 0, 95% ≈ 0.49 mm.
- A ball and the sample block are reported unreliable with no figures.

## Deviations From the Design

- `ScanLibrary.attach(report:to:)` is `attachReport(_:to:)` and takes encoded bytes,
  so Library does not depend on the accuracy code.
- `ScanStoring`'s two new methods have protocol-extension fallbacks (read nil, write
  fails) so existing test stores in other files did not need editing.
- `Alignment.align` takes points (`[Vec3]`), not a `PointCloud` type; the pipeline
  samples the mesh first. `AlignmentResult` uses `rmsResidual`/`inlierFraction`/`coverage`.
- Background removal (AC-6) and the inlier-share test in the reliability rule were
  added beyond ADR-009 (sweep scans include the table).
- Unreliable reports are saved too, and set the library tick.
- Accuracy screen has no Compare methods or Export yet (U11).

## Not Verified

- Everything on the phone: screens, VoiceOver, large text, sideways layouts; timing of a
  real check (expected a few seconds for 20,000 points); background removal on a real
  sweep; thresholds on real scans (ADR-009 calls them provisional). Covered by the
  checklist, items 12–20 after Bolts 6 and 7 merge.
- No real cross-component end-to-end run with a captured scan was possible in this
  Bolt (capture is in Bolts 6 and 7); the Core pipeline was tested end to end on
  synthetic scans and the real STL.
- Compiler warnings in the app build (CI shows only the last 40 lines).
