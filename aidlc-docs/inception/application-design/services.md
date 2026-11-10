# Services — ScanLab (LidarApp)

Inputs: `components.md`, `component-methods.md`, `requirements.md`, `stories.md`,
`decisions.md`. No prior `architecture` artefact exists.

There are no network services (ADR-001). "Service" here means a long-lived object inside
the app that coordinates several components. There are four, plus the build pipeline
outside the app.

## Service Definitions

| Service | Responsibility | Coordinates | Stories |
|---|---|---|---|
| **CaptureService** (`CaptureCoordinator`) | Runs a capture from start to saved scan, for either method; turns sensor events into guidance; survives interruption | `SweepCapturing` or `PhotoCapturing`, `FeedbackPlaying`, ScanLibrary, `Logging` | US-06–US-09 |
| **LibraryService** (`ScanLibrary`) | The single owner of scans on disk; all reads and writes of scan data go through it | `ScanStoring`, `Logging` | US-10, US-11 |
| **AccuracyService** | Runs alignment, deviation, fitting and reporting off the main thread; stores reports | ReferenceModel, Alignment, Deviation, FeatureFitting, AccuracyReporting, LibraryService | US-12–US-14 |
| **ExportService** | Simplifies, writes the file to a temporary place, hands it to the system's save chooser; exports raw captures, findings, logs and reports the same way | MeshSimplifier, MeshFiles, LibraryService | US-11, US-02, US-04 |

## Orchestration

**Orchestration, not choreography.** Each service is the one caller that sequences its
components; components do not react to each other's events. With one process and one
user, a central sequence is easier to follow in the diagnostics log than a web of
notifications.

```
Capture:   Screen → CaptureService → capturer port ──events──> CaptureService
                         │  (cue)                                   │ (on finish)
                         └──> FeedbackPlaying                       └──> LibraryService → ScanStoring

Accuracy:  Screen → AccuracyService → Alignment → Deviation → FeatureFitting → AccuracyReporting
                                                                    └──> LibraryService (attach report)

Export:    Screen → ExportService → MeshSimplifier → MeshFiles → temp file → system save chooser
```

Text fallback: the capture screen calls CaptureService, which drives a capturer port,
receives its events, plays guidance cues and on finish saves through LibraryService. The
accuracy screen calls AccuracyService, which runs alignment, deviation, fitting and
reporting in order and attaches the report through LibraryService. The export screen
calls ExportService, which simplifies, writes a temporary file and passes it to the
system's save chooser.

## Communication Contracts

| From → To | Style | Contract |
|---|---|---|
| Screen model → service | Direct async call | Returns a value or throws a typed error |
| Service → screen model | Async stream | `CaptureEvent`, build `Progress`; delivered on the main actor |
| Service → port | Direct async call | Core types only; no platform types cross |
| Any → `Logging` | Synchronous, non-throwing | One `LogEvent` per notable step and per error |

Every service call that can take more than a moment reports progress and can be
cancelled; cancellation leaves saved scans untouched (NFR-8).

## Lifecycle and Capacity

| Service | Created | Lives | Concurrency |
|---|---|---|---|
| LibraryService | At launch | Whole app run | An actor: one writer at a time |
| CaptureService | When a capture starts | Until the scan is saved or discarded; state persisted on interruption (FR-5.4) | One capture at a time |
| AccuracyService | On first use | Whole app run | Background task; one report at a time |
| ExportService | On first use | Whole app run | Background task; one export at a time |

Scaling does not apply: one user, one device. The limits that matter are memory and
storage on the phone. Large meshes and raw captures are streamed to and from disk, not
held whole in memory where avoidable, and storage is checked before a capture, a build
or an export starts (NFR-9).

## The Build Pipeline (outside the app)

| Stage | Does | Fails the run when |
|---|---|---|
| Check | Formatting and lint | Any finding |
| Test | Core tests with coverage | A test fails or Core coverage is under 80% |
| Build | Generate project, compile for the device, sign | Compile or signing error |
| Deliver | Upload to TestFlight | Upload rejected |

Triggers: push to `main`, manual run, monthly schedule (ADR-014). The duration of each
run is recorded (NFR-12).
