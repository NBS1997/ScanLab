# Code Summary — U09 part 1, Subject Box and Coverage Dome (Bolt 10a)

## Core (`Packages/ScanLabCore/Sources/ScanLabCore/Subject`)

| File | What it does |
|---|---|
| `SubjectBox.swift` | The world-aligned box, its resize with floor kept, `SubjectMask` (Vision outline on a grid), `SubjectPickError` with messages. |
| `SubjectFinder.swift` | Depth readings to world points; tapped point; subject by outline or 15 cm reach; supporting surface by most common height; percentile box with margins. |
| `SubjectChoice.swift` | Choosing → finding → proposed → locked, or Scan everything; instructions. |
| `CoverageDome.swift` | 24 patches (8 round × 3 heights), counting fused pictures with the box in view; next-patch prompts. |

Changed: `DepthFusion` takes an optional `region` (only cubes inside are fused; readings
landing outside are skipped); `FusionSettings.boxed` (3 mm, 12 mm band); `SweepProgress`
carries `coverage`, whose prompt follows tracking and memory prompts.

## App (`App/Sources/Capture`)

| File | What it does |
|---|---|
| `SubjectPicker.swift` | Holds a tap until the next frame, copies depth and colour pictures, maps the tap through the inverted display transform, runs Vision and `SubjectFinder` on a background queue. |
| `SubjectMasker.swift` | `VNGenerateForegroundInstanceMaskRequest`; keeps the instance under the tap, sampled to 256 × 192. |
| `SubjectBoxOutline.swift` | 12 thin RealityKit bars, yellow or green. |
| `CoverageRingView.swift` | The dome as three rings of 8, current patch outlined. |
| `SweepReceiver.swift` | Moved out of `ARKitSweepCapture.swift`; fusion waits for scanning; coverage recorded per fused picture; milestones logged. |
| `ARKitSweepCapture.swift`, `LiveSweepCapturing.swift` | Port gains `pickSubject`, `showSubject`, `beginScanning`. |
| `CaptureModel.swift`, `CaptureView.swift` | Tap layer, Smaller / Bigger / Scan this / Scan everything, ring, success buzz; Finish needs scanning. |

## Tests

`SubjectTests` (synthetic block on a table: box with and without outline, table cut,
taps on the table and on nothing, tiny outline; box resize limits; choice flow; dome
directions, counting, left/right and height prompts; region fusion; prompt order).
CI run 43210913896: 455 tests passed, Core coverage 98.8%, app builds.

## Not testable in CI

Vision's outline on real pictures, the display-transform mapping of taps, RealityKit
drawing, and speed at 3 mm. See `docs/checklists/bolt-10a-subject-box.md`.
