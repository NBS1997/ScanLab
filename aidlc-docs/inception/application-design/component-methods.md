# Component Methods — ScanLab (LidarApp)

Inputs: `components.md`, `requirements.md`, `stories.md`, `decisions.md`. Signatures are
indicative Swift; detailed rules belong to Functional Design. No prior `architecture`
artefact exists.

## Error Approach

- Fallible operations are `throws` (or `async throws`) with a typed error per component
  (`MeshFileError`, `AlignmentError`, `StoreError`, `CaptureError`). No error is
  swallowed: it is either handled, or logged through `Logging` and surfaced to the
  screen as an in-place message (mockups Q3-A).
- Recoverable conditions that are part of normal use (tracking lost, unreliable match)
  are **values**, not errors.
- Adapters translate platform errors into the Core error types; platform types do not
  cross the boundary.

## Core

### Geometry

| Method | Purpose | In → Out | Errors |
|---|---|---|---|
| `Mesh.init(vertices:triangles:)` | Build a mesh | arrays → `Mesh` | Precondition on index range |
| `Mesh.boundingBox` | Overall size | — → `Box` (metres) | — |
| `Mesh.faceCount` | Face count | — → `Int` | — |
| `Mesh.transformed(by:)` | Move a mesh | `Transform` → `Mesh` | — |

### MeshSimplifier

| Method | Purpose | In → Out | Errors |
|---|---|---|---|
| `simplify(_ mesh:, targetFaces:)` | Reduce to at most the target | `Mesh`, `Int` → `Mesh` | `SimplifyError.cannotReach` if the target is below what the shape allows |
| `ExportDetail.targetFaces(for:)` | Full / Fusion-friendly (10,000) / Light (5,000) | `Mesh` → `Int` | — |

### MeshFiles

| Method | Purpose | In → Out | Errors |
|---|---|---|---|
| `write(_ mesh:, as:, to:)` | Write STL or OBJ in millimetres | `Mesh`, `MeshFormat`, `URL` | `MeshFileError.writeFailed(reason)`, `.noSpace` |
| `read(from:)` | Read OBJ (from Object Capture) | `URL` → `Mesh` | `MeshFileError.malformed(line)` |

### Alignment

| Method | Purpose | In → Out | Errors |
|---|---|---|---|
| `align(scan:, to:)` | Coarse then fine alignment | `PointCloud`, `ReferenceObject` → `AlignmentResult` (transform, residual, coverage, iterations) | `AlignmentError.tooFewPoints` |
| `MatchQuality.init(result:)` | Rate the match | `AlignmentResult` → `.good / .fair / .unreliable` with numbers | — |

### Deviation and FeatureFitting

| Method | Purpose | In → Out | Errors |
|---|---|---|---|
| `deviation(of:, from:)` | Surface error by region | aligned `PointCloud`, `ReferenceObject` → `[RegionDeviation]` | — |
| `measure(_ feature:, in:)` | Dimension of one feature | `Feature`, aligned `PointCloud` → `Measurement?` | Returns `nil` with a reason when the fit fails; not thrown |

### ReferenceModel

| Method | Purpose | In → Out | Errors |
|---|---|---|---|
| `ReferenceObject.load(from:)` | Load bundled shape and feature table | `URL` → `ReferenceObject` | `ReferenceError.malformed` |
| `setCaliperValue(_:, for:)` | Record the owner's measurement | `Double`, `Feature.ID` | `ReferenceError.unknownFeature` |

### AccuracyReporting

| Method | Purpose | In → Out | Errors |
|---|---|---|---|
| `makeReport(scan:, reference:)` | Full pipeline | `Mesh`, `ReferenceObject` → `AccuracyReport` | Propagates `AlignmentError` |
| `AccuracyReport.isReliable` | Whether figures may be shown | — → `Bool` | — |
| `AccuracyReport.verdict` | One-sentence summary | — → `String` | — |
| `compare(_:, _:)` | Two methods side by side | two reports → `Comparison` | — |
| `csv(_ report:)` | Spreadsheet export | report → `String` | — |

### ScanLibrary

| Method | Purpose | In → Out | Errors |
|---|---|---|---|
| `all()` | List scans, newest first | — → `[Scan]` | `StoreError` |
| `add(mesh:, method:, detail:)` | Save a finished scan | → `Scan` | `StoreError.noSpace`, `.writeFailed` |
| `rename(_:, to:)`, `delete(_:)` | Manage scans | `Scan.ID` | `StoreError.notFound` |
| `keepRawCapture(_:, keep:)` | Keep or discard raw data | `Scan.ID`, `Bool` | `StoreError` |
| `storage(for:)` | Bytes for model and raw capture | `Scan.ID` → `StorageUse` | — |
| `attach(report:, to:)` | Store an accuracy report | | `StoreError` |

### CaptureSession

| Method | Purpose | In → Out | Errors |
|---|---|---|---|
| `CaptureCoordinator.start(method:)` | Begin a capture | `CaptureMethod` | `CaptureError.permissionDenied`, `.sensorUnavailable` |
| `events` | Guidance and progress | — → async stream of `CaptureEvent` (tooFast, trackingLost, recovered, coverage, progress) | — |
| `finish()` | Build the model | — → `Scan` | `CaptureError.buildFailed(reason)` |
| `interrupt()` / `resume()` | Keep what was captured | | — |
| `discard()` | Drop a capture | | — |

### Diagnostics and Units

| Method | Purpose | In → Out | Errors |
|---|---|---|---|
| `Logging.log(_ event:)` | Record an event | `LogEvent` | Never throws; a failed write is counted and reported at next success |
| `Logging.recent(limit:)` | Read back | `Int` → `[LogEvent]` | — |
| `Logging.exportText()` | Export | — → `String` | — |
| `Units.format(_ metres:)` | mm, or m at 1 m and over | `Double` → `String` | — |

## Ports (implemented by adapters)

| Port | Methods | Notes |
|---|---|---|
| `SweepCapturing` | `start()`, `events`, `finish() -> Mesh`, `pause()`, `resume()`, `stop()` | Mesh in metres |
| `PhotoCapturing` | `start()`, `events`, `finish() -> RawCapture`, `build(from:) -> Mesh` with progress, `detailLevel` | Build is restartable from a `RawCapture` |
| `SensorFeeding` | `frames` (async stream of `SensorFrame`: image, depth, confidence), `centreDistance`, `frameRate` | Frames are opaque handles to Core |
| `HardwareProbing` | `describe() -> HardwareDescription`, `captureDepthStill() -> DepthStill` | Every value read at runtime (PC4) |
| `EdgeDetecting` | `edges(in frame:) -> EdgeOverlay` | Rate-limited by the adapter |
| `ScanStoring` | `list()`, `read(_:)`, `write(_:)`, `remove(_:)`, `size(_:)`, `rawCaptureURL(_:)` | Atomic writes |
| `FeedbackPlaying` | `play(_ cue: GuidanceCue)` | Haptic, tone and spoken announcement together |
| `BuildDescribing` | `version`, `build`, `buildDate`, `expiryDate` | Expiry = build date + 90 days |
| `Logging` | as above | Injected everywhere |
