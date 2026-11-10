# Domain Entities — U10 Accuracy Stage 1

Inputs: `component-methods.md` (ReferenceModel, Alignment, Deviation, AccuracyReporting, ScanLibrary `attach(report:to:)`), `components.md`, `decisions.md` (ADR-007, ADR-009), `reference-object/output/feature-table.json`, `unit-of-work.md` (U10, U11).

All lengths inside Core are metres; report figures are stored in millimetres (the
unit shown). Feature regions stay in millimetres, as in the table.

## Reference model (`Accuracy/ReferenceModel.swift`, `CaliperValues.swift`, `STLReading.swift`)

| Entity | Fields | Notes |
|---|---|---|
| `ReferenceObject` | `mesh` (metres), `table` | `load(stlData:featureTableData:)`: binary STL in mm → metres; `ReferenceError` on failure. |
| `FeatureTable` | `version`, `smallLimit`, `mediumLimit` (mm), `features`, `skippedFeatures` | Tolerant: unknown fields ignored, unreadable features skipped and counted, duplicate IDs refused. `label(for:)` gives "Small (up to 5 mm)". |
| `ReferenceFeature` | `id`, `kind`, `summary`, `designValue`, `unit` (mm / deg), `sizeMillimetres`, `sizeClass`, `howToMeasure`, `region` (Box, mm) | JSON keys `description`, `sizeMm`, `measure`. |
| `FeatureKind` | length, step, hole, boss, angle, curve, other | Unknown kinds read as `other`; `groupTitle` from the measurement sheet. |
| `SizeClass` | small, medium, large | Comparable (small first). |
| `CaliperSheet` | `version`, `tableVersion`, `values` (ID → value in the feature's unit), `updatedAt?` | JSON, ISO 8601, tolerant. `set(_:for:in:)` validates. |
| `CaliperCheck` | `empty`, `valid(value, warning?)`, `invalid(reason)` | From `CaliperValidation.check` (AC-2–AC-4). |
| `ReferenceError` | `malformedShape`, `malformedTable`, `degenerateShape`, `unknownFeature` | Reason-and-next-step descriptions. |
| `CaliperError` | `invalid(featureID:reason:)`, `unreadable` | |

## Alignment and deviation

| Entity | Fields | Notes |
|---|---|---|
| `ReferenceSurface` | `reference`, search index, visible samples (3,000, underside excluded), centroid, principal axes, diagonal, feature regions (metres, smallest class first) | Built once; refuses an empty or flat shape. |
| `SurfaceIndex` (internal) | Box tree of triangles (≤ 4 per leaf) | `nearest(to:within:)` → point, face normal, distance. |
| `SurfacePoint` | `position`, `normal` | From `SurfaceSampler` (area-weighted, seeded). |
| `IsolationResult` | `points`, `removed`, `supportHeight?` | AC-6. |
| `AlignmentSettings` | screening 200, starts 8, coarse 400 × 10 rounds, fine 4,000 × 40 rounds, inlier 5 mm, smallest trim 1 mm, coverage radius 3 mm, minimum 100 points | |
| `AlignmentResult` | `transform` (scan → reference), `rmsResidual`, `inlierFraction`, `coverage`, `iterations`, `startsTried` | |
| `AlignmentError` | `tooFewPoints(found:needed:)` | |
| `DeviationStats` | `count`, `mean`, `rms`, `within95`, `maximum` (metres) | |
| `DeviationResult` | `overall`, `bySizeClass`, `otherSurface`, `excluded` | AC-9, AC-10. |

## Report (`Accuracy/AccuracyReport.swift`, `AccuracyReporting.swift`)

| Entity | Fields | Notes |
|---|---|---|
| `AccuracyReport` (v1) | `version`, `scanID`, `createdAt`, `match`, `isReliable`, `verdictLevel`, `verdict`, `reasons`, `overall?`, `sizeClasses`, `transform` (12 numbers: rotation rows, then move in metres), `pointsUsed`, `backgroundRemoved`, `caliperValuesEntered`, `stepMilliseconds` | Stored as `accuracy-report.json`. Tolerant decoding; figures are dropped when not reliable. **Room for U11:** new optional fields (per-feature results, feature-kind summary) are added without a version change; `transform` lets stage 2 reuse the alignment. |
| `MatchSummary` | `rmsMillimetres`, `coverage`, `inlierFraction`, `iterations`, `startsTried`, `quality` | |
| `MatchQuality` | good, fair, unreliable | AC-13. |
| `VerdictLevel` | good, limited, unreliable | AC-14. |
| `SizeClassResult` | `sizeClass?` (nil = whole surface or rest of surface), `label`, `pointCount`, `meanMillimetres`, `rmsMillimetres`, `within95Millimetres`, `maximumMillimetres` | |
| `ReliabilityRule` | 2 mm, 60%, 50%; good at 0.5 mm and 80%; trusted spread 1 mm | AC-11. |
| `AccuracyRequest` | `scanID`, `surface`, `caliperValuesEntered`, `alignment`, `rule`, `scanPoints` (20,000), `createdAt` | Input to `AccuracyPipeline.run`. |
| `AccuracyProgress` | `step` (sampling, isolating, aligning, measuring), `fraction` | |

## Ports and services

| Name | Kind | Change |
|---|---|---|
| `ScanStoring` | Port (Core) | Added `reportData(for:)` and `replaceReport(_:for:)`; fallbacks for stores without reports (read nil, write fails). |
| `ScanLibrary` | Service (Core actor) | Added `attachReport(_:to:)` (sets `hasAccuracyReport`) and `reportData(for:)`. Reports are passed as bytes so the library does not depend on the accuracy code. |
| `FileScanStore` | Adapter | `accuracy-report.json`, atomic write. |
| `AccuracyService` | Service (App) | `savedReport(for:)`, `run(scanID:progress:)` (background, cancellable). |
| `BundledReference` | App actor | Loads the bundled STL and table once. |
| `CaliperStore` | App | Reads and writes the caliper sheet. |
