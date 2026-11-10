# Component Dependencies — ScanLab (LidarApp)

Inputs: `components.md`, `services.md`, `component-methods.md`, `requirements.md`,
`stories.md`, `decisions.md`. No prior `architecture` artefact exists.

## Dependency Rules

1. **App → Core, never the reverse.** Core imports only the Swift standard library and
   Foundation.
2. **Screens → Core services and ports.** Screens never name an adapter type.
3. **Adapters → platform frameworks and Core types.** Adapters never depend on screens
   or on each other.
4. **Within Core, lower layers do not know higher ones:**
   Geometry ← MeshFiles, MeshSimplifier, Alignment ← Deviation, FeatureFitting ←
   AccuracyReporting. No cycles.

The build checks rule 1 structurally: Core is a separate package and cannot compile if
it imports an App or sensor framework.

## Dependency Matrix (Core)

Rows depend on columns.

| | Geometry | Units | Diagnostics | Ports | ReferenceModel | Alignment | Deviation | FeatureFitting | MeshFiles | MeshSimplifier |
|---|---|---|---|---|---|---|---|---|---|---|
| MeshSimplifier | ● | | | | | | | | | |
| MeshFiles | ● | | | | | | | | | |
| ReferenceModel | ● | | | | | | | | ● | |
| Alignment | ● | | | | ● | | | | | |
| Deviation | ● | | | | ● | ● | | | | |
| FeatureFitting | ● | | | | ● | ● | | | | |
| AccuracyReporting | ● | ● | ● | | ● | ● | ● | ● | | |
| ScanLibrary | ● | | ● | ● | | | | | ● | |
| CaptureSession | ● | | ● | ● | | | | | | |

Geometry, Units, Diagnostics and Ports depend on nothing in Core.

## Dependency Matrix (App)

| Screen | Core services | Ports used |
|---|---|---|
| Library | LibraryService | — |
| NewScan, Capture | CaptureService | `FeedbackPlaying` (through the service) |
| ScanDetail | LibraryService | `EdgeDetecting` |
| Export | ExportService | — |
| Explore | — | `SensorFeeding`, `EdgeDetecting` |
| HardwareDetails | LibraryService (findings) | `HardwareProbing` |
| Accuracy | AccuracyService, LibraryService | — |
| Diagnostics | — | `Logging`, `BuildDescribing` |

## Data Flow

```
Sweep:   depth sensor → ARKitSweepCapture → Mesh ─┐
Photos:  cameras+depth → ObjectCapturePhotoCapture → RawCapture → OBJ → MeshFiles.read → Mesh ─┤
                                                                                               v
                                                              LibraryService → scan folder (manifest, mesh, raw)
                                                                   │                    │
                                              ExportService <──────┘                    └──> AccuracyService
                                   simplify → STL/OBJ → save chooser          align → deviation → fit → report
                                                                                         └──> scan folder (report)
```

Text fallback: both capture methods end in a Core mesh. The sweep adapter produces one
directly; the photo adapter produces a raw capture, then an OBJ that Core reads into a
mesh. LibraryService stores the mesh, manifest and optional raw capture in the scan's
folder. ExportService reads a scan, simplifies it and writes STL or OBJ for the save
chooser. AccuracyService reads a scan, aligns it to the reference, computes deviation
and fitted measurements, and stores the report back in the scan's folder.

## Communication Patterns

| Pattern | Where | Why |
|---|---|---|
| Direct async call | Screen → service → component | One process; simplest to trace in the log |
| Async stream | Capturer and sensor ports → service → screen | Continuous events (guidance, frames, progress) |
| Actor isolation | LibraryService | One writer to scan storage |
| Main actor | Screen models | Interface updates |

No event bus, no notifications between components, no shared mutable singletons.

## Shared Resources

| Resource | Shared by | Rule |
|---|---|---|
| Camera and depth sensor | Capture, Explore, HardwareDetails (depth still) | One holder at a time; a screen releases the sensor when it disappears. Capture has priority. |
| Scan storage folder | LibraryService only | All access through the service's actor |
| Log file | Every component, through `Logging` | Appends are serialised by the adapter |
| Bundled reference object | ReferenceModel | Read-only; caliper values stored separately in app storage |
| Phone storage and memory | Capture, build, export | Checked before starting; failures are clean (NFR-9) |

## External Dependencies

| Dependency | Used by | Shipped in app | Licence |
|---|---|---|---|
| Apple frameworks (SwiftUI, ARKit, RealityKit, AVFoundation, Vision, SceneKit, Core Haptics) | App adapters and screens | Part of the system | Platform |
| XcodeGen | Build | No | MIT |
| SwiftLint | Build | No | MIT |
| CadQuery | reference-object script | No | Apache 2.0 |

Nothing third-party is shipped in the app (ADR-008).
