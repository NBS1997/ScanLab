# Domain Entities — U07 Sweep Capture (with Explore additions)

Inputs: `component-methods.md` (CaptureSession, `SweepCapturing`), `components.md`, `decisions.md` (ADR-003, ADR-005), U07 `business-rules.md`.

All in Core (`Packages/ScanLabCore/Sources/ScanLabCore/`), Foundation only.

## Capture (`Capture/`)

| Entity | Kind | Holds / does |
|---|---|---|
| `CapturePhase` | enum | idle, preparing, capturing, finishing, saved(UUID), failed(CaptureError), cancelled; `isOver`, `logName` |
| `CaptureSessionEvent` | enum | start, sensorReady, finish, saved(UUID), fail(CaptureError), cancel |
| `CaptureSession` | struct | the current phase and the table of allowed steps (`allows`, `apply` throwing `CaptureTransitionError`) |
| `CaptureError` | enum, `LocalizedError` | permissionDenied, sensorUnavailable, sessionFailed, nothingCaptured, noSpace, saveFailed, buildFailed; `init(wrapping:)` maps library and other errors |
| `SweepCapturing` | port (protocol) | `start() -> SweepStreams`, `finish() async throws -> Mesh` (y-up metres), `cancel()`; all main-actor |
| `SweepStreams` | struct | `progress: AsyncStream<SweepProgress>`, `statuses: AsyncStream<SensorStatus>` (reuses the live sensor's statuses) |
| `SweepProgress` | struct | anchorCount, faceCount, elapsed, tracking |
| `SweepTracking`, `TrackingLimit` | enums | normal / limited(initialising, movingTooFast, tooLittleDetail, relocalising, other) / notAvailable; `prompt`, `logName` |
| `MeshPart` | struct | one reconstructed piece: local corners, triangles, `Transform` into the world |
| `MeshAssembly` | namespace | `assemble(parts, weldTolerance:, crop:) -> AssembledMesh`; weld 0.5 mm; minimum face area 1e-8 m² |
| `AssemblyReport` | struct | partsUsed, facesIn, invalidFaces, degenerateFaces, croppedFaces, weldedVertices; `logDetails` |
| `Transform(columnMajor:)` | initialiser | from the 16 values of a 4 × 4 matrix stored column by column |
| `SweepCaptureService` | main-actor class | CaptureService: drives the port with the session rules, turns the mesh z-up, saves via `ScanLibrary.add(mesh:method: .sweep)`, logs |
| `CaptureText` | namespace | "00:42", spoken time, "12 areas · 34,560 faces" |

## Explore additions (`Sensors/`)

| Entity | Kind | Holds / does |
|---|---|---|
| `DepthColourMap.closeRange(centredOn:halfWidth:)` | factory | narrow map centre ± half-width (near end ≥ 0); nil for an invalid centre or band; `isNarrow` |
| `CloseRangeBand` | struct | half-width (choices ±2/±5/±10 cm), centre with hysteresis (`follow`), `colourMap`, labels |
| `DepthQualityInput` | struct | depths, confidence, recentDistance; `centre(of:side:)` copies the central square. Bolt 11 adds edge evidence here. |
| `DepthAdvice` | enum | good, moveCloser, moveBack; `hint`, `logName` |
| `PoorDepthAdvisor` | namespace | `advice(for:)` with named first-guess thresholds |
| `SteadyValue<Value>` | struct | holds a changing value back until it has persisted for a hold time |

## App side (not Core)

| Entity | Role |
|---|---|
| `LiveSweepCapturing` | `SweepCapturing` plus `makeCameraView()` |
| `ARKitSweepCapture` / `SweepReceiver` | adapter: ARKit world tracking with `sceneReconstruction = .mesh`, RealityKit `ARView` showing the mesh, anchors kept on a serial queue, copied into `MeshPart`s at Finish |
| `PreviewSweepCapture` | stand-in for previews |
| `CaptureModel` | Capture screen state mirrored from `SweepCaptureService` |
