# LidarApp — Architecture Decisions

Why things are the way they are. Before changing something that seems suboptimal, check
here first. **If a decision is documented below, it was deliberate** — don't refactor it
without raising the reversal explicitly.

Each entry is numbered permanently. IDs are referenced from commits, code comments and
other docs, so they are never reused and never renumbered.

ADR-001 to ADR-016 come from the AI-DLC inception
(`aidlc-docs/inception/application-design/decisions.md`, which also records security and
reversibility notes for each). They are summarised here; the inception file is the full
record. ADR-017 onwards were made during construction (Bolts 1–8 and the
`fix-file-paths` fix) and are taken from the Bolt code summaries, functional designs and
code comments.

"Core" means the `ScanLabCore` package; "App" means the iPhone app target.

---

## ADR-001: Build a native Swift and SwiftUI app with no server

**Date:** 2026-11
**Status:** Active
**Context:** One user, one phone, fully offline, no data leaving the phone. Capture needs
the platform's depth, tracking and Object Capture frameworks, which are native-only.
**Decision:** A single native Swift app: SwiftUI screens, Swift concurrency for
background work, the Observation framework for screen state. No backend, accounts or
network code.
**Consequences:** Direct access to every sensing capability. Building needs Apple tools
on a hosted Mac. The owner cannot read Swift yet, so code must be explained in plain
language. Nothing is reusable on other platforms.
**Alternatives rejected:** React Native or Flutter (every sensor would need a
hand-written native bridge, with no second platform to benefit); a web app (no depth
sensor access).

## ADR-002: Stable build tools and minimum iOS 26, moving to iOS 27 tools later

**Date:** 2026-11
**Status:** Active
**Context:** The phone runs iOS 27, but the hosted runner's stable image has Xcode 26
with iOS 26 SDKs; the Xcode 27 image is a preview.
**Decision:** Build with Xcode 26 on `macos-26`, deployment target iOS 26.0, Swift 6
language mode. Revisit when Xcode 27 is generally available.
**Consequences:** No iOS 27-only features until the move; the app relies on forward
compatibility on iOS 27.
**Alternatives rejected:** Preview iOS 27 tools (a preview image can break, and every
break costs a round trip with no Mac); an older toolset (Apple requires Xcode 26 or
later for uploads).

## ADR-003: Ports and adapters, with a pure-Swift Core package

**Date:** 2026-11
**Status:** Active
**Context:** Sensor code cannot run in the hosted build, yet sensor-independent logic
needs 80% coverage and tests in every build, and the accuracy maths must be provably
right on synthetic input.
**Decision:** `ScanLabCore` is a Swift package that imports only Foundation and holds
geometry, simplification, file formats, alignment, accuracy reporting, the library model
and the log model. It defines ports (protocols) for what it needs from the phone. The App
target holds SwiftUI screens and thin adapters that implement the ports with ARKit,
RealityKit, AVFoundation and the file system. App depends on Core; Core depends on
nothing.
**Consequences:** Core is tested with `swift test` on the runner with coverage. What
cannot be tested automatically is kept small and covered by on-device checklists. Costs
some indirection and more files.
**Alternatives rejected:** A single app target tested in the simulator (depth and Object
Capture do not run there); Core in a separate repository (overhead with one consumer).

## ADR-004: Generate the project file with XcodeGen

**Date:** 2026-11
**Status:** Active
**Context:** There is no Mac to open or edit an Xcode project.
**Decision:** The app is described in `project.yml`; XcodeGen generates the project on
the runner. No `.xcodeproj` is committed (it is in `.gitignore`).
**Consequences:** The project definition is a short text file that can be edited on
Windows. XcodeGen is a build-time tool installed on the runner. Settings XcodeGen does
not know need its escape hatches.
**Alternatives rejected:** A committed project file (large, opaque, unsafe to edit
without Apple's tools); a Swift package only (cannot produce a signed app with
permissions and icons).

## ADR-005: Sweep capture uses ARKit scene reconstruction

**Date:** 2026-11
**Status:** Active
**Context:** Sweep capture needs a surface model from moving the phone over a subject,
tracking events for guidance, and a live depth layer.
**Decision:** An ARKit world-tracking session with scene reconstruction for the model,
scene depth and confidence for the live layers, and ARKit's tracking state for guidance.
The reconstructed mesh is copied into Core's `Mesh` at Finish.
**Consequences:** Least code for a working sweep. Mesh detail is whatever ARKit gives
(room-oriented); the accuracy report quantifies it. No control over the meshing.
**Alternatives rejected:** Fusing depth frames ourselves (large, untestable
sensor-side code; reconsider only if accuracy figures justify it); a camera depth stream
without ARKit (no tracking, so views cannot be combined).

## ADR-006: Photo capture uses on-device Object Capture, keeping photographs and poses

**Date:** 2026-11
**Status:** Active
**Context:** Photo capture needs a model from photographs with true size. The platform
provides guided capture and on-device reconstruction, limited to reduced detail on
iPhone. The owner asked for raw-capture export.
**Decision:** Use Object Capture for guided capture and `PhotogrammetrySession` for
reconstruction at the highest detail the phone allows, output as OBJ and converted to
Core's mesh. Photographs and camera poses are kept in the scan's folder when the owner
chooses.
**Consequences:** A working photo pipeline with little code. Detail is capped, which is
the main accuracy risk. The platform's capture view limits customisation.
**Alternatives rejected:** Our own photogrammetry (far beyond MVP scope); server
reconstruction (breaks offline, privacy and no-cost rules); reconstruction on the
Windows PC as the only route (makes a third-party tool mandatory; kept as an option
through raw-capture export).

## ADR-007: One folder per scan with a JSON manifest; no database

**Date:** 2026-11
**Status:** Active
**Context:** Scans must survive relaunch, crashes and updates; storage per scan must be
visible and freeable; raw captures are large.
**Decision:** Each scan is a folder in Application Support with a small JSON manifest,
the mesh file, a thumbnail, and optionally the raw capture and accuracy report. The
library is built by reading manifests. Writes go to a temporary name and are renamed
into place.
**Consequences:** Nothing to migrate, easy to inspect; storage is a folder size. Listing
cost grows with scan count, acceptable for one user.
**Alternatives rejected:** SwiftData or Core Data (schema migrations risk data loss on
update, and nothing needs queries); a single library file (one bad write loses every
scan).

## ADR-008: Platform frameworks by default; exceptions case by case

**Date:** 2026-11
**Status:** Active
**Context:** No-cost and no-sign-up rules; a small build machine.
**Decision:** Only Apple's frameworks and our own code ship in the app. Exceptions are
recorded here with licence and reason; so far they are build-time tools only: XcodeGen
(MIT), SwiftLint (MIT) and CadQuery (Apache 2.0, reference object only).
**Consequences:** We own simplification, alignment and file writing (ADR-009, ADR-013):
more code, all in Core and under test. No supply-chain exposure in the shipped app.
**Alternatives rejected:** Free libraries where convenient (build time, licence checks,
code the owner cannot evaluate); no exceptions at all (would forbid the required linter).

## ADR-009: Accuracy in two stages — surface deviation, then feature fitting

**Date:** 2026-11
**Status:** Active (stage 1 built in Bolt 8; stage 2 not yet built)
**Context:** The owner wants automatic comparison with the reference object. The report
must state match quality and refuse to show figures when the match is poor.
**Decision:** Stage 1: align the scan to the reference (coarse alignment from overall
shape, refined by ICP) and report scan-to-reference surface distance per size class.
Match quality is the alignment residual together with coverage of the reference. Stage
2: fit planes, cylinders and spheres per feature and compare with caliper values.
Initial thresholds (unreliable when residual is over 2 mm or coverage under 60%) are
provisional and tuned on the phone.
**Consequences:** An answer to "how accurate is it?" a stage earlier. Both stages run on
synthetic scans in CI. Stage 1 figures are surface distances, not dimensions, and are
labelled so.
**Alternatives rejected:** Feature fitting only (fragile on rough scans); surface
deviation only (no per-feature caliper comparison); owner-picked alignment points (the
owner asked for no manual measuring).

## ADR-010: Generate the reference object from a CadQuery script

**Date:** 2026-11
**Status:** Active
**Context:** The app needs the reference object's exact shape and feature table; the
owner needs a printable file and a Fusion file. Drift between them would invalidate
every accuracy figure.
**Decision:** `reference-object/reference_object.py` (CadQuery) writes an STL, a STEP,
the feature table JSON and the measurement sheet from one run. Outputs are committed.
`project.yml` bundles the STL and feature table straight from `reference-object/output/`.
**Consequences:** One source of truth. CadQuery runs in the `reference-object.yml`
workflow (it is not installed on the PC); outputs are downloaded from CI and committed
by hand.
**Alternatives rejected:** Designing in Fusion (feature table kept by hand would drift);
OpenSCAD (cannot write STEP).

## ADR-011: Append-only diagnostics log behind one logging port

**Date:** 2026-11
**Status:** Active
**Context:** With no Mac, faults must be diagnosable from the phone.
**Decision:** Core defines a `Logging` port. The App's `FileLog` appends one JSON line
per event, flushed on every write, trimmed to the most recent 5,000 lines at launch, and
mirrored to the system log. Nothing writes to the console; the Diagnostics screen reads
and exports the same file.
**Consequences:** Entries survive crashes; one place to export. SwiftLint rule
`no_console_output` enforces the convention.
**Alternatives rejected:** System log only (unreadable without a Mac); a third-party
crash or analytics service (breaks privacy and no-sign-up rules).

## ADR-012: Edge detection with the Vision framework

**Date:** 2026-11
**Status:** Active (not yet built; the Explore Edges toggle is disabled with "Coming in a
later build")
**Context:** Edges from the camera are wanted live and on a scan.
**Decision:** Run Vision contour detection on camera frames at a reduced rate and draw
the result as a layer; on scan detail, over the scan's source picture. No projection of
edges into 3D in the MVP.
**Consequences:** Low effort and risk; does not improve the model itself.
**Alternatives rejected:** Our own GPU edge filter (more sensor-side code for the same
picture); edges from depth discontinuities (coarse depth grid; possible later layer).

## ADR-013: Mesh simplification and STL/OBJ writers in Core

**Date:** 2026-11
**Status:** Active
**Context:** Fusion needs 10,000 faces or fewer; exports must be true-size millimetres.
**Decision:** Quadric-error simplification and binary STL and OBJ writers in Core, with
millimetres as the export unit. 3MF deferred.
**Consequences:** Export behaves identically in CI and on the phone and is fully tested.
Simplification quality is ours to get right (see ADR-026).
**Alternatives rejected:** Model I/O export (only checkable on the phone, no
simplification); an open-source mesh library (a shipped dependency for two
well-understood algorithms).

## ADR-014: Reuse the fishing app's build workflow; deliver on merge; monthly rebuild

**Date:** 2026-11
**Status:** Superseded by ADR-016
**Context:** A build-and-deliver workflow existed in another of the owner's repositories;
the team practice was delivery on every merge; TestFlight builds expire after 90 days.
**Decision:** Copy that workflow, run checks before the build, deliver from GitHub on
every push to `main`, on demand and monthly.
**Consequences:** Would have needed the App Store Connect key in the public repository's
secrets.
**Alternatives rejected:** A new minimal workflow (re-solves signing with no Mac); a
hosted third-party build service (needs a sign-up).

## ADR-015: Name the app ScanLab; license the repository MIT

**Date:** 2026-11
**Status:** Active
**Context:** The owner chose the name and licence; a licence was needed before
publishing a public repository.
**Decision:** Display name ScanLab; the repository folder is LidarApp (GitHub
`NBS1997/ScanLab`); MIT licence; bundle ID `com.nbs1997.scanlab`.
**Consequences:** Anyone may reuse the code with attribution. Repository and app names
differ, which the docs state once.
**Alternatives rejected:** Apache 2.0 (patent grant not needed); no licence (public code
with no stated rights).

## ADR-016: Deliver with the builder CLI from the PC; CI checks on every push

**Date:** 2026-11
**Status:** Active. Supersedes ADR-014.
**Context:** The owner's existing TestFlight setup is the `builder` CLI on the Windows
PC. Its GitHub workflow (`ios-build.yml`) only builds and signs; upload and TestFlight
hand-off happen from the PC with an App Store Connect key stored there.
**Decision:** `ci.yml` runs the signing-material check, lint, format, Core tests with
coverage and an unsigned compile on every push and pull request. After each Bolt merges,
`builder ios release --profile store` is run from the PC. `ios-build.yml` is
builder-managed and not edited by hand. The monthly rebuild becomes a reminder on the PC.
**Consequences:** The App Store Connect key never enters the public repository.
Delivery depends on the PC and the builder tool, so "every merge delivers automatically"
is met in effect, not literally (recorded in `.claude/rules/aidlc-project.md`).
**Alternatives rejected:** Upload from GitHub on merge (key in a public repo's secrets);
our own workflow (re-solves signing builder already handles).

---

## ADR-017: Explore draws the camera with ARSCNView and colours overlays in Core

**Date:** 2026-11 (Bolt 4)
**Status:** Active
**Context:** The Explore screen shows the live camera with depth and confidence overlays
at 30 fps or more. Converting ARKit's 1920 × 1440 YCbCr camera image to a picture every
frame would cost far more per frame.
**Decision:** An `ARSCNView` sharing `LiveSensorFeed`'s `ARSession` draws the camera
picture on the GPU. The 256 × 192 depth or confidence grid is coloured and rotated to the
interface orientation in Core (`DepthColourMap`, `OverlayRenderer`, `RGBAImage`), turned
into a `CGImage` in the App and drawn aspect-fill over the same rectangle. `SensorFrame`
carries no camera image, so Core holds no image handle.
**Consequences:** Cheap camera drawing; overlay maths is tested in CI. `ARSCNView` belongs
to SceneKit, which the sweep capture work found deprecated as of iOS 26 (ADR-018); it may
produce deprecation warnings. Explore has not been moved to RealityKit.
**Alternatives rejected:** Converting `capturedImage` per frame (per-frame cost risks the
frame-rate target).

## ADR-018: Sweep capture uses RealityKit ARView, not ARSCNView

**Date:** 2026-11 (Bolt 6)
**Status:** Active
**Context:** Sweep capture shows the reconstructed surface growing over the camera
picture. SceneKit, and so `ARSCNView`, is deprecated as of iOS 26.
**Decision:** `ARKitSweepCapture` uses one RealityKit `ARView` for the app's lifetime,
with `.showSceneUnderstanding`, which draws the reconstruction as a wireframe itself.
**Consequences:** No geometry code per mesh update. Explore and sweep capture now use two
different AR view types. Whether one shared `ARView` behaves well across many captures is
not yet verified on the phone.
**Alternatives rejected:** `ARSCNView` with our own SceneKit mesh drawing (deprecated
framework, and geometry rebuilt on every update).

## ADR-019: Store scan models in the SLMESH01 binary format

**Date:** 2026-11 (Bolt 5)
**Status:** Active
**Context:** Each saved scan needs its model on disk. OBJ keeps four decimals and STL
keeps 4-byte floats, so either would change a scan slightly every save; OBJ is also
large and slow to parse.
**Decision:** `mesh.slmesh`, written by Core's `MeshBinary`: little-endian, 8-byte magic
`SLMESH01`, `UInt32` vertex count, `UInt32` face count, then x, y, z per vertex as
`Float64` metres (24 bytes) and three `UInt32` indices per face (12 bytes). Total size is
exactly 16 + 24V + 12F bytes; any other length, wrong magic or out-of-range index is
`StoreError.corrupt`. Exports still use STL and OBJ.
**Consequences:** Bit-exact round trips; about 4.8 MB for 200,000 faces; truncated files
are detected. The format is ours, so other tools cannot open it directly, and any layout
change needs a new magic string and a reader for the old one.
**Alternatives rejected:** OBJ (lossy, two to three times larger, slow to read); STL
(lossy 4-byte floats, no shared vertices).

## ADR-020: The ScanStoring port is synchronous and byte-based

**Date:** 2026-11 (Bolt 5)
**Status:** Active
**Context:** The inception design had `list/read/write/size/rawCaptureURL` on the store
port. Decoding manifests and models belongs where it can be tested.
**Decision:** `ScanStoring` deals in bytes (`scanIDs`, `manifestData`, `meshData`,
`thumbnailData`, `create`, `replaceManifest`, `remove`, `storage`, later raw-capture and
report methods) and is synchronous. The `ScanLibrary` actor is the single writer and does
all decoding in Core. Free space comes in through an `availableBytes` closure. Methods
added later (reports) have protocol-extension fallbacks so existing test stores still
compile.
**Consequences:** One writer at a time without locks in the adapter; manifest and model
decoding are tested against `MemoryScanStore` in CI. `FileScanStore` stays a thin file
adapter.
**Alternatives rejected:** The inception's richer, URL-based port (pushes decoding into
untested App code).

## ADR-021: Use URL.fileSystemPath, never URL.path(), for file-system calls

**Date:** 2026-11 (`fix-file-paths`)
**Status:** Active
**Context:** `URL.path()` percent-encodes the result, so the space in "Library/Application
Support" became `%20` and every `FileManager` existence check failed. In build 4 a saved
sweep opened as "This scan could not be found".
**Decision:** Core's `URL.fileSystemPath` (`path(percentEncoded: false)`, in
`Files/URL+FileSystemPath.swift`) is used for every path string given to `FileManager`.
SwiftLint custom rule `no_escaped_file_path` makes `.path()` an error. Regression tests
(`FileSystemPathTests` and others) use a folder named "Application Support".
**Consequences:** One helper to remember; the linter catches the mistake.
**Alternatives rejected:** Fixing call sites one by one with no lint rule (the mistake is
natural to write again).

## ADR-022: Object Capture at reduced detail, OBJ output read by Core

**Date:** 2026-11 (Bolt 7)
**Status:** Active
**Context:** On iPhone, `PhotogrammetrySession` only offers `.reduced` detail. Core needs
the model as a `Mesh`. `ObjectCaptureView` needs the concrete `ObjectCaptureSession`.
**Decision:** `ObjectCapturePhotoCapture` requests `.modelFile` to a folder (which
produces OBJ, per Apple's documentation) at `.reduced`, plus `.poses`. If the OBJ request
fails, it builds once more as USDZ from the saved checkpoint and converts to OBJ with
Model I/O; the route is logged. Core's `PhotoModelImport` reads the OBJ with `OBJReader`,
welds coincident corners and converts to z-up. Camera positions are written as CSV. The
`PhotoCapturing` port covers detail level, preparation and building; guided capture lives
in the App screen model, which holds the session. Raw captures are exported as a zip made
with `NSFileCoordinator`'s `.forUploading`.
**Consequences:** Model import is tested in CI. Detail is capped by the platform. The OBJ
route and the USDZ fallback are both unverified on the phone. The photo flow has its own
`PhotoCaptureFlow` state machine rather than sharing the sweep's `CaptureSession`.
**Alternatives rejected:** USDZ as the main route (needs Model I/O conversion every time);
a port that hides the capture session (impossible with `ObjectCaptureView`).

## ADR-023: Accuracy alignment — 20,000 samples, 36 starting guesses, trimmed point-to-plane ICP

**Date:** 2026-11 (Bolt 8)
**Status:** Active
**Context:** ADR-009 needs automatic alignment with no owner input, fast on the phone for
any scan size, and accurate enough to prove 0.05 mm on synthetic scans.
**Decision:** `AccuracyPipeline` samples every scan to 20,000 points evenly by area with
a fixed seed. `Alignment` builds 36 starting guesses (24 pairings of principal axes, 12
turns of 30° about the vertical), ranks them on 200 points, roughly refines the best 8 on
400 points for 10 rounds, then refines the best on 4,000 points for up to 40 rounds with
point-to-plane ICP against the true reference triangles (`SurfaceIndex`, a box tree).
Each round uses only points within three times the median distance, never under 1 mm.
Fewer than 100 points is an error.
**Consequences:** Work does not grow with scan size; the same scan always gives the same
report. In CI the pose is recovered to well under 0.05 mm. Real-scan timing on the phone
is not yet measured.
**Alternatives rejected:** Matching to reference sample points instead of triangles
(leaves an error of about half the sample spacing); owner-picked points (see ADR-009);
a grid for nearest-triangle search (the reference mixes huge and tiny triangles).

## ADR-024: Accuracy reliability rule and background removal

**Date:** 2026-11 (Bolt 8)
**Status:** Active (thresholds provisional)
**Context:** A poor match must show no figures. Sweep scans include the table, and after
trimming almost any shape finds some close points.
**Decision:** `ReliabilityRule` marks a report unreliable when coverage (share of the
reference's visible surface, underside excluded, with a scan point within 3 mm) is under
60%, or the RMS of points within 5 mm is over 2 mm, or under 50% of the
background-removed scan lies within 5 mm. Good match: RMS ≤ 0.5 mm and coverage ≥ 80%;
otherwise fair. An unreliable report stores and shows no figures. `ScanIsolation` removes
the table and keeps the largest connected piece when a scan is more than 1.5 times the
reference's size. One report per scan is saved as `accuracy-report.json`, unreliable ones
included.
**Amended 2026-11-11 (outside review):** points more than 5 mm from the reference are
still left out of the figures, but the report now records how many (`pointsMeasured`,
`pointsExcluded`), the verdict states the left-out share and the share of the reference
with no scan within 3 mm, and more than 10% left out
(`ReliabilityRule.maximumExcludedShare`) caps a good rating at limited (rule AC-19). The
library and Scan detail seal shows the verdict level (good, limited, unreliable), not
just that a report exists.
**Consequences:** Coverage is the decisive test for "another object". The inlier test
and background removal go beyond ADR-009. Thresholds are untested on real scans.
**Alternatives rejected:** ADR-009's residual and coverage tests alone (a scan that is
mostly table or another object could pass).

## ADR-025: Store everything z-up; convert from y-up once, at save

**Date:** 2026-11 (Bolts 5–7)
**Status:** Active
**Context:** ARKit and Object Capture produce y-up meshes. Fusion and most CAD tools
expect z-up, and the library's thumbnails and viewer assume z-up (rule SL-13).
**Decision:** Both capture paths call `Mesh.convertedFromYUp()` (`Geometry/AxisConversion.swift`;
(x, y, z) → (x, −z, y), a pure rotation) once, just before saving. Everything stored,
shown, aligned or exported is z-up, in metres internally and millimetres in exports.
**Consequences:** One conversion point per capture method; accuracy alignment relies on
z-up to find the table and the vertical.
**Alternatives rejected:** Converting at display or export time (every consumer would
have to remember).

## ADR-026: Simplifier breaks ties by edge length and caps merged-vertex neighbours at 24

**Date:** 2026-11 (Bolt 3)
**Status:** Active
**Context:** On flat areas every edge collapse costs nothing, so merges piled into the
lowest-numbered vertex, building "hub" vertices with hundreds of neighbours. The
simplifier went quadratic and the 79,360-face test exceeded its time limit in CI.
**Decision:** `EdgeCollapser` adds a tiny cost growing with edge length (`lengthWeight`
1e-3 on the fourth power of length) so short edges go first, and refuses merges that
would leave a vertex with more than 24 neighbours (`maximumValence`). Regression test: "no
vertex ends up joined to too many others".
**Consequences:** Even face shrinkage and predictable run time. These look like magic
numbers but removing them brings the slowdown back.
**Alternatives rejected:** Raising the test's time limit (hides a real slowdown on the
phone).

## ADR-027: Show scans with SceneKit SCNView

**Date:** 2026-11 (Bolt 5)
**Status:** Active
**Context:** Scan detail needs a turnable, zoomable model of up to about 200,000 faces,
built without a Mac to try alternatives.
**Decision:** `ModelView` wraps SceneKit's `SCNView`, whose built-in camera control gives
turn, zoom and move with no gesture code, and which lights the model itself.
**Consequences:** SceneKit no longer gains features (and is deprecated as of iOS 26, per
ADR-018), so the view is kept small and self-contained for a later swap.
**Alternatives rejected:** RealityKit (newer, but its non-AR camera controls on iPhone
need more setup that could not be tried without a Mac).

## ADR-028: Export through UIDocumentPickerViewController in copy mode

**Date:** 2026-11 (Bolt 3)
**Status:** Active
**Context:** Exported files must keep exactly the name ScanLab gives them, and the
temporary file must be removed afterwards.
**Decision:** `ExportService` writes a temporary file (after a free-space check) and
presents `UIDocumentPickerViewController` in export-as-copy mode; the temporary file is
removed when the picker finishes.
**Consequences:** A small UIKit bridge instead of a SwiftUI modifier.
**Alternatives rejected:** SwiftUI `.fileExporter` (less control over the saved name and
the temporary file).

---

Format for new entries:

```markdown
## ADR-0NN: <short imperative title>

**Date:** YYYY-MM
**Status:** Active
**Context:** <what forced a choice: the constraint, the problem>
**Decision:** <what was chosen, in one or two sentences>
**Consequences:** <what this costs and commits the project to, including the bad parts>
**Alternatives rejected:** <each alternative, and why it lost>
```

<!--
Statuses:
  Active               — in force
  Superseded by ADR-0NN — replaced; entry kept for the historical record
  Deprecated           — no longer applies, not replaced

Not everything needs an ADR. The test: would a competent newcomer look at this and
try to "fix" it? If yes, write the entry. If it is just a preference with no forcing
constraint, leave it out — a log full of trivia stops being read.
-->
