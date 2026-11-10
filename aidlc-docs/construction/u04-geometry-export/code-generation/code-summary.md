# Code Summary — Bolt 3 (Geometry and Export, U04)

Inputs: `unit-of-work.md` (U04), `bolt-plan.md` (Bolt 3), `business-rules.md`, `domain-entities.md`, `components.md`, `component-methods.md`, `decisions.md` (ADR-003, ADR-008, ADR-013), `mockups.md`, `interaction-spec.md`.

## What Was Built

| Area | Files | Notes |
|---|---|---|
| Geometry | `Packages/ScanLabCore/Sources/ScanLabCore/Geometry/` | `Vec3` (Double), `Box`, `Transform`, `Triangle`, `Mesh` (checked indices, bounding box, volume, area, open-edge count, transform, compact) |
| Simplifier | `Quadric.swift`, `EdgeHeap.swift`, `MeshSimplifier.swift`, `CollapseChecks.swift` | Quadric-error edge collapse with a priority queue and lazy deletion; border planes for open scans; link-condition, duplicate-face and fold-over checks; deterministic tie-breaking; `SimplifyError.cannotReach` / `.invalidTarget` |
| Detail levels | `ExportDetail.swift` | Full / Fusion-friendly (≤ 10,000) / Light (≤ 5,000); `ExportNaming` for safe file names |
| Files | `Files/MeshFiles.swift`, `Files/OBJReader.swift` | Binary STL (84 + 50·n bytes) and OBJ, both in millimetres; OBJ reader (quads, `v/t/n`, negative indices, line-numbered errors); storage-full detection; atomic writes |
| Units | `Units/Units.swift` | mm to 0.1 mm, or m at 1 m and over; Australian number format; face-count text |
| Sample | `Geometry/SampleMeshes.swift` | Closed stepped block with boss, 60 × 40 × 20 mm; 310 coarse faces, 19,840 after 3 subdivisions |
| Core tests | 9 new suites in `Tests/ScanLabCoreTests/` | See the CI run for counts and coverage |
| App | `App/Sources/Export/ExportService.swift`, `Screens/ExportModel.swift`, `Screens/ExportView.swift` | Simplify off the main thread → temporary file (free-space check first) → the phone's save chooser (`UIDocumentPickerViewController`, copy); every step logged under `export`; errors shown in place |
| Entry point | `Screens/DiagnosticsView.swift`, `DiagnosticsModel.swift` | New "Sample model" section with **Export sample model…** |
| Lint config | `.swiftlint.yml` | `identifier_name` allows x, y, z, a, b, c (maths names) |

## Sample Face Counts

| Level | Faces |
|---|---|
| Full | 19,840 |
| Fusion-friendly | ≤ 10,000 (tests require 9,990–10,000) |
| Light | ≤ 5,000 (tests require 4,990–5,000) |

## Deviations From the Design

- **Save chooser:** a UIKit document picker in export-as-copy mode rather than SwiftUI
  `.fileExporter`, so the saved file keeps exactly the name we give it and the
  temporary file can be removed afterwards.
- **No raw-capture switch** on the Export screen yet; it arrives with photo capture
  (U08, FR-7.5), when there is a raw capture to export.
- **`Mesh.init` throws** (`MeshError`) instead of a precondition, so bad OBJ data or a
  bad adapter cannot crash the app.
- **Simplifying to zero faces** is reported as `cannotReach` rather than returning an
  empty model.
- `.swiftlint.yml` gained an `identifier_name` exclusion list. Bolt 4 runs in parallel;
  if it changes the same file, the merge needs a manual join of both blocks.

## Issues Found and Fixed in CI

1. SwiftLint: a two-letter name (`up`) and `x = x + y` in a test.
2. swift-format: one test line over 120 columns.
3. Type checker timed out on a one-line cube-corner expression in a test helper.
4. **Simplifier slowed to quadratic time on flat areas**: zero-cost merges all went into
   the lowest-numbered vertex, building "hub" vertices with hundreds of neighbours (the
   79,360-face test exceeded its time limit). Fixed with a tiny edge-length tie-break,
   so short edges go first, and a cap of 24 neighbours per merged vertex; regression
   test "no vertex ends up joined to too many others". Sample simplifications are now
   computed once per test run.

## Not Verified

- Anything on the phone: the Export sheet, the save chooser (its button wording), iCloud
  Drive saving, aeroplane mode, Dynamic Type, VoiceOver and rotation. Covered by
  `docs/checklists/bolt-03-geometry-export.md`.
- That Fusion converts the Fusion-friendly file to a solid and measures 60 × 40 × 20 mm
  within 0.1% (the Bolt's confidence hypothesis, R5); Blender and slicer loading.
- Simplification time on the phone for 200,000 faces; CI only runs a 79,360-face case
  under a two-minute limit in a debug build.
- The storage-full path on a real full phone (unit-tested through simulated errors and
  a free-space figure only).
