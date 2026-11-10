# Units of Work — ScanLab (LidarApp)

Inputs: `components.md`, `component-methods.md`, `services.md`,
`component-dependency.md`, `decisions.md`, `requirements.md`, `stories.md` and
`units-generation-questions.md` (feature slices, about 13 Units, parallel where
allowed).

Each Unit is a **feature slice**: it cuts through whatever screen, Core logic and adapter
the capability needs, and ends in something the owner can try on the phone (or, for
U03, on the printer). Every Unit is delivered as part of the one app (ADR-001), except
U03, which lives in `reference-object/`.

Complexity: **S** a day or so of work, **M** a few days, **L** a week, **XL** more.

## Units

### U01 Delivery skeleton
- **Delivers:** an almost-empty ScanLab app that builds on the hosted runner, is signed,
  and arrives on the phone through TestFlight; opens on an empty library screen; shows
  version, build date and expiry on a Diagnostics screen.
- **Owns:** `project.yml`, the build workflow (lint, Core tests with coverage, build,
  deliver, monthly schedule), the empty Core package with its test target, the
  Composition root, `BuildDescribing`, app icon and camera purpose statement, MIT
  licence, README.
- **Requirements:** FR-1.1–1.4, NFR-1, NFR-4, NFR-5, NFR-10–12.
- **Complexity:** M. **Notes:** risk R8 (reused workflow) lives here; keep the app
  almost empty so a failure is a pipeline failure.

### U02 Diagnostics log
- **Delivers:** the activity log, written by every later Unit, readable and exportable
  from Diagnostics.
- **Owns:** Core `Diagnostics` (`Logging` port, `LogEvent`), `FileLog` adapter, the
  Diagnostics screen's log list and export, the lint rule forbidding direct console
  output.
- **Requirements:** FR-10.1–10.4, NFR-8. **Complexity:** S.

### U03 Reference object
- **Delivers:** a printable reference object, a Fusion-readable design file, the feature
  table the app bundles, and a caliper measurement sheet.
- **Owns:** `reference-object/` (CadQuery script and generated files).
- **Requirements:** FR-8.1–8.5. **Complexity:** M.
- **Notes:** no app code; needs CadQuery on the owner's computer or a build job. Must be
  asymmetric (FR-8.3) and carry all five feature kinds at three or more sizes.

### U04 Geometry and mesh export
- **Delivers:** Core geometry types, mesh simplification and binary STL and OBJ writers
  in millimetres, plus the Export screen with detail levels and the system save chooser.
- **Owns:** Core `Geometry`, `Units`, `MeshSimplifier`, `MeshFiles`; `ExportService`;
  Export screen.
- **Requirements:** FR-7.1–7.4, FR-6.4 (dimensions), PC2. **Complexity:** L.
- **Notes:** fully testable in the build. Delivered with a built-in sample mesh so export
  can be tried on the phone before any capture exists.

### U05 Scan library
- **Delivers:** scans stored one folder each, listed with thumbnail, name, method, date
  and size; rename and delete; Scan detail with a turnable model.
- **Owns:** Core `ScanLibrary`, `ScanStoring` port, `FileScanStore` adapter,
  `LibraryService`; Library and Scan detail screens.
- **Requirements:** FR-6.1–6.4, FR-6.6 (storage figures), NFR-8, NFR-9.
  **Complexity:** M.

### U06 Live sensor view
- **Delivers:** Explore with camera, depth and confidence layers, centre distance and
  frame rate.
- **Owns:** `SensorFeeding` port, `LiveSensorFeed` adapter, Explore screen (without the
  edges layer).
- **Requirements:** FR-2.1 (three layers), FR-2.2, NFR-7. **Complexity:** M.
- **Notes:** first sensor-dependent Unit; on-device checklist required.

### U07 Sweep capture
- **Delivers:** New scan → Sweep → Finish → a saved scan.
- **Owns:** Core `CaptureSession` state machine and `SweepCapturing` port;
  `ARKitSweepCapture` adapter; CaptureService; New scan and Capture screens (basic, no
  guidance yet).
- **Requirements:** FR-3.1–3.3. **Complexity:** L.

### U08 Photo capture
- **Delivers:** New scan → Photos → model built on the phone with progress, detail
  level shown, raw capture kept or discarded on request, raw capture exportable.
- **Owns:** `PhotoCapturing` port, `ObjectCapturePhotoCapture` adapter, OBJ reading into
  Core, raw-capture storage and export.
- **Requirements:** FR-4.1–4.4, FR-6.6, FR-7.5. **Complexity:** XL.
- **Notes:** the central accuracy risk (R1, PC1); background building behaviour is
  unknown (requirements Open Question 3).

### U09 Capture guidance and interruption
- **Delivers:** haptics, tones and spoken alerts; coverage on screen; interrupted
  captures kept with Continue or Build.
- **Owns:** `FeedbackPlaying` port, `SystemFeedback` adapter, guidance events and
  interruption states in `CaptureSession`, Capture screen overlays.
- **Requirements:** FR-5.1–5.4. **Complexity:** M.

### U10 Accuracy stage 1: alignment and surface deviation
- **Delivers:** mark a scan as the reference object, enter caliper values, check
  accuracy, and get match quality, a verdict and surface error by size class.
- **Owns:** Core `ReferenceModel`, `Alignment`, `Deviation`, the report model and
  reliability rule in `AccuracyReporting`; `AccuracyService`; Accuracy and Reference
  object screens.
- **Requirements:** FR-8.6, FR-9.1–9.4, FR-9.6 (by size class), FR-9.9 (alignment and
  deviation). **Complexity:** L.
- **Notes:** proven on synthetic scans with known error in the build before any real
  scan is tried.

### U11 Accuracy stage 2: feature fitting and comparison
- **Delivers:** per-feature caliper vs scan table, error by feature kind, side-by-side
  comparison of capture methods, CSV export.
- **Owns:** Core `FeatureFitting`, comparison and CSV in `AccuracyReporting`; Compare
  methods screen.
- **Requirements:** FR-9.5–9.8, FR-9.9 (fitting). **Complexity:** L.

### U12 Edge detection
- **Delivers:** the edges layer live in Explore and over a scan's source picture.
- **Owns:** `EdgeDetecting` port, `VisionEdgeDetector` adapter, edges layer on Explore
  and Scan detail.
- **Requirements:** FR-2.1 (edges), FR-6.5. **Complexity:** S.

### U13 Hardware details and findings
- **Delivers:** the list of what the phone reports (depth formats, cameras, lens and
  offset data, camera combinations, export types), findings notes, findings export, and
  the higher-resolution depth still.
- **Owns:** `HardwareProbing` port, `HardwareProbe` adapter, Hardware details screen,
  findings storage.
- **Requirements:** FR-2.3–2.6. **Complexity:** M.

## Summary

| Unit | Complexity | Sensor-dependent | Testable in build |
|---|---|---|---|
| U01 Delivery skeleton | M | No | Partly (build itself) |
| U02 Diagnostics log | S | No | Yes |
| U03 Reference object | M | No | Script output checks |
| U04 Geometry and export | L | No | Yes |
| U05 Scan library | M | No | Core yes; screens on phone |
| U06 Live sensor view | M | Yes | No |
| U07 Sweep capture | L | Yes | State machine only |
| U08 Photo capture | XL | Yes | OBJ reading only |
| U09 Guidance and interruption | M | Yes | Event rules only |
| U10 Accuracy stage 1 | L | No | Yes |
| U11 Accuracy stage 2 | L | No | Yes |
| U12 Edge detection | S | Yes | No |
| U13 Hardware details | M | Yes | No |
