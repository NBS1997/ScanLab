# Components — ScanLab (LidarApp)

Inputs: `requirements.md`, `stories.md`, `decisions.md` (ADR-001 to ADR-015). No prior
`architecture` artefact exists (greenfield).

## Structure

```
+--------------------------- App target (ScanLab) ---------------------------+
|  Screens (SwiftUI)                                                         |
|   Library · NewScan · Capture · ScanDetail · Export · Explore ·            |
|   HardwareDetails · Accuracy · Diagnostics                                 |
|  Adapters (implement Core's ports with platform frameworks)                |
|   ARKitSweepCapture · ObjectCapturePhotoCapture · LiveSensorFeed ·         |
|   HardwareProbe · VisionEdgeDetector · FileScanStore · FileLog ·           |
|   SystemFeedback · BuildInfo                                               |
+----------------------------------|-----------------------------------------+
                                   v  depends on
+------------------------ ScanLabCore (pure Swift) --------------------------+
|  Geometry · MeshSimplifier · MeshFiles · Alignment · Deviation ·           |
|  FeatureFitting · ReferenceModel · AccuracyReporting · ScanLibrary ·       |
|  CaptureSession · Diagnostics · Units · Ports                              |
+----------------------------------------------------------------------------+

Outside the app:  reference-object/ (CadQuery script)   .github/workflows/ (build)
```

Text fallback: the App target contains SwiftUI screens and adapters; it depends on
ScanLabCore, a pure-Swift package of geometry, accuracy, library and diagnostics logic
that defines ports. Core depends on nothing. A reference-object script and the build
workflow sit outside the app.

**Boundary rule:** Core never imports a camera, depth, graphics or interface framework.
Adapters contain no decisions, only translation. Screens talk to Core and to ports, never
to an adapter's concrete type.

## Core Components (ScanLabCore)

| Component | Purpose | Owns | Public surface | Requirements |
|---|---|---|---|---|
| Geometry | Shapes and maths | `Mesh` (vertices, triangles, normals), `PointCloud`, vectors, transforms, bounding box | Value types and pure functions | FR-6.4 |
| MeshSimplifier | Reduce face count | Quadric-error simplification | `simplify(mesh, targetFaces)` | FR-7.3, PC2 |
| MeshFiles | Write and read model files | Binary STL and OBJ writers, OBJ reader, millimetre scaling | `write(mesh, format, to)`, `read(from)` | FR-7.1, FR-7.2 |
| Alignment | Line a scan up with the reference | Coarse alignment, iterative closest point, residual and coverage | `align(scan, reference)` → transform + match quality | FR-9.2, FR-9.3 |
| Deviation | Surface error | Point-to-surface distances grouped by feature region and size class | `deviation(alignedScan, reference)` | FR-9.6 (stage 1) |
| FeatureFitting | Measure features | Plane, cylinder and sphere fitting; dimension from fitted primitives | `measure(feature, alignedScan)` | FR-9.5 (stage 2) |
| ReferenceModel | The known truth | Reference mesh, feature table, owner's caliper values | `ReferenceObject`, `Feature`, load from bundled JSON | FR-8.4, FR-8.6 |
| AccuracyReporting | Turn numbers into a report | Report model, verdict sentence, reliability rule, comparison, CSV | `makeReport(...)`, `compare(a, b)`, `csv(report)` | FR-9.1–9.9 |
| ScanLibrary | Scans as data | `Scan` manifest, naming, sorting, storage accounting, state (building, partial, has report) | `ScanLibrary` over the `ScanStoring` port | FR-6.1–6.3, FR-6.6, NFR-9 |
| CaptureSession | Capture rules | State machine for a capture (starting, capturing, interrupted, building, done, failed), guidance events, coverage | `CaptureCoordinator` over capture ports | FR-3, FR-4, FR-5 |
| Diagnostics | What happened | `LogEvent`, levels, formatting, trimming rule | `Logging` port, `LogEvent` | FR-10 |
| Units | Display | Millimetres, metres at 1 m and over, formatting | `format(length)` | FR-6.4, Q6-B |
| Ports | What Core needs from the phone | Protocol definitions only | See `component-methods.md` | ADR-003 |

## App Components — Adapters

| Adapter | Implements port | Uses | Requirements |
|---|---|---|---|
| ARKitSweepCapture | `SweepCapturing` | ARKit world tracking, scene reconstruction | FR-3, FR-5.1 |
| ObjectCapturePhotoCapture | `PhotoCapturing` | Object Capture session, photogrammetry session | FR-4, FR-7.5 |
| LiveSensorFeed | `SensorFeeding` | ARKit camera image, scene depth, confidence | FR-2.1, FR-2.2 |
| HardwareProbe | `HardwareProbing` | Camera framework device discovery, formats, calibration, multi-camera sets | FR-2.3, FR-2.6 |
| VisionEdgeDetector | `EdgeDetecting` | Vision contour detection | FR-2.1, FR-6.5 |
| FileScanStore | `ScanStoring` | File system, atomic writes | FR-6.3, NFR-8 |
| FileLog | `Logging` | File system, system log | FR-10.1–10.3 |
| SystemFeedback | `FeedbackPlaying` | Haptic generators, system sounds, screen-reader announcements | FR-5.1, FR-5.3 |
| BuildInfo | `BuildDescribing` | App bundle information | FR-1.3 |

## App Components — Screens

One SwiftUI view and one observable model per screen, matching `mockups.md`.

| Screen | Model depends on | Stories |
|---|---|---|
| Library | ScanLibrary | US-10 |
| NewScan | CaptureSession | US-06, US-07 |
| Capture | CaptureSession, `FeedbackPlaying` | US-06–US-09 |
| ScanDetail | ScanLibrary, `EdgeDetecting` | US-05, US-07, US-10 |
| Export | MeshSimplifier, MeshFiles, ScanLibrary | US-11 |
| Explore | `SensorFeeding`, `EdgeDetecting` | US-03, US-05 |
| HardwareDetails | `HardwareProbing`, ScanLibrary (findings store) | US-04 |
| Accuracy | ReferenceModel, Alignment, Deviation, FeatureFitting, AccuracyReporting | US-12–US-14 |
| Diagnostics | `Logging`, `BuildDescribing` | US-01, US-02 |

A small **Composition** component at app start creates the adapters and hands them to
the screen models; it is the only place concrete adapter types are named.

## Outside the App

| Component | Purpose | Requirements |
|---|---|---|
| reference-object/ | CadQuery script producing the STL, STEP, feature table and measurement sheet | FR-8.1–8.5, ADR-010 |
| Build workflow | Lint, test Core with coverage, build, sign, deliver, monthly rebuild | FR-1.1, FR-1.4, NFR-10–12, ADR-014 |
| project.yml | Project definition for XcodeGen | ADR-004 |
