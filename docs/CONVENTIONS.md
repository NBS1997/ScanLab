# LidarApp — Conventions

Single source of truth for how code is written here. Every change is reviewed against
this document. Much of it is enforced by `.swiftlint.yml` and `.swift-format`, both run
with `--strict` in CI, so a warning fails the build.

## Language & Spelling

- **Australian English** throughout — colour, favourite, centre, behaviour, organise,
  licence (noun) / license (verb). Applies to identifiers, comments, commit messages,
  UI strings and documentation. Examples in the code: `DepthColourMap`, `RGBAColour`,
  `CentreSampler`. Apple API names keep Apple's spelling (`UIColor`, `.center`).
- Prose in documentation is plain and direct. No filler.
- **Explain non-obvious code in plain language** (project rule: the owner relies on
  AI-written code). Every type has a `///` comment saying what it is for, and the "why"
  of any surprising choice is written next to it, with the ADR or business-rule ID where
  one exists. `MeshBinary.swift` and `FileScanStore.swift` are good examples.

## Types & Naming

Swift API Design Guidelines, plus:

| Thing | Convention | Example |
|---|---|---|
| Files | One main type per file, named after it; extensions as `Type+Topic.swift` | `MeshSimplifier.swift`, `URL+FileSystemPath.swift`, `PhotoCaptureModel+Building.swift` |
| Types | UpperCamelCase. Ports are `-ing` protocols; adapters are named by their technology | `SweepCapturing` → `ARKitSweepCapture`; `ScanStoring` → `FileScanStore`, `MemoryScanStore` |
| Functions and properties | lowerCamelCase (swift-format `AlwaysUseLowerCamelCase`) | `convertedFromYUp()`, `fileSystemPath` |
| Constants | `static let` on the owning type, with a comment giving the unit and reason | `EdgeCollapser.maximumValence`, `AlignmentSettings.inlierDistance` |
| Short names | Only `id`, `x`, `y`, `z`, `a`, `b`, `c` are allowed under SwiftLint's minimum length (coordinates and triangle corners) | `Vec3(x, y, z)`, `Triangle(a, b, c)` |
| Screens | `<Name>View` and an `@MainActor @Observable` `<Name>Model` | `ExportView`, `ExportModel` |
| Test files | `<Subject>Tests.swift` with a `@Suite("…")` | `MeshBinaryTests.swift` |

Units go in names when a value is not in metres: `rmsMillimetres`, `sizeMm`,
`stepMilliseconds`. Internal lengths are metres (`Double`), with no suffix.

**Escape hatches.** Force unwraps and `try!` are banned by swift-format
(`NeverForceUnwrap`, `NeverUseForceTry`). `@unchecked Sendable` is allowed only with a
comment explaining what makes it safe (for example a lock or a private serial queue; see
`MemoryLog`, `SweepReceiver`). `// swiftlint:disable:next <rule>` is used sparingly and
only for one line (two uses of `cyclomatic_complexity` exist, on large `switch`
statements).

## File Size Limits

| Kind | Limit | When exceeded |
|---|---|---|
| Line | 120 columns (swift-format and SwiftLint warning; 160 is a SwiftLint error) | Wrap |
| Source file, type body, function body | SwiftLint's default `file_length`, `type_body_length` and `function_body_length`; `--strict` makes the warning level fail CI | Split by topic into `Type+Topic.swift` extensions, or extract helpers |

The repository does not override SwiftLint's size defaults; check the SwiftLint version
CI installs for the exact numbers. The largest source files are about 380 lines.

## Import Order

Imports are sorted alphabetically (swift-format `OrderedImports`), one block, with
`@testable import` in its own block after a blank line in tests:

```swift
import ARKit
import Foundation
import RealityKit
import ScanLabCore
import UIKit
```

Core files import only `Foundation`. Test files import `Foundation` and `Testing`, then
`@testable import ScanLabCore`.

## Error Handling

- **Fallible operations throw typed errors.** Each Core area has an `enum …Error: Error,
  Equatable, Sendable` with a `LocalizedError` extension whose text is plain words for
  the owner, often with what to do next (`StoreError`, `MeshError`, `MeshFileError`,
  `SimplifyError`, `CaptureError`, `PhotoCaptureError`, `AlignmentError`,
  `ReferenceError`, `CaliperError`). Bad input data throws rather than crashing
  (`Mesh.init` throws `MeshError` rather than using a precondition).
- **Adapters translate platform errors** into Core's error types; Core rules decide what
  happens next.
- **Screen models turn errors into screen state** (for example `.failed(reason)`), using
  `localizedDescription`, and show them in place.
- **Never swallow a failure silently.** Every failure is logged through the `Logging`
  port at `warning` or `error`, with a `reason` detail. `Logging.log` itself never throws
  and never blocks (BR-1, BR-4); a failed log write is counted and reported with the next
  successful one.
- **Log call shape:** `log.info("<category>", "<Sentence case message>", ["key": "value"])`.
  Categories in use: `app`, `log`, `library`, `export`, `sensor`, `capture`, `photo`,
  `accuracy`.
  Details are strings: counts, durations (`ms`), short IDs, reasons.
- **Never log** photographs, file contents, mesh data or caliper sheets — event names,
  counts, durations and error reasons only (ADR-011).
- **No console output.** `print`, `debugPrint` and `NSLog` are SwiftLint errors
  (`no_console_output`).

## Code Patterns

| Pattern | Reference implementation |
|---|---|
| Port in Core, adapter in App | `Packages/ScanLabCore/Sources/ScanLabCore/Library/ScanStoring.swift` → `App/Sources/Library/FileScanStore.swift` |
| In-memory fake for tests and previews | `MemoryScanStore` (`Library/ScanStoring.swift`), `MemoryLog` (`Diagnostics/Logging.swift`) |
| Composition root | `App/Sources/AppEnvironment.swift` |
| Single-writer state | `ScanLibrary` actor (`Library/ScanLibrary.swift`) |
| State machine in Core, adapter only translates | `Capture/CaptureSession.swift`, `Capture/Photo/PhotoCaptureFlow.swift` |
| Crash-safe write (stage, then rename) | `FileScanStore.create` |
| Sensor callbacks on a private serial queue, copied into Core values | `App/Sources/Sensors/LiveSensorFeed.swift` (`FrameReceiver`) |
| Background work with progress and cancellation | `AccuracyPipeline.run` with `Task.checkCancellation()`; `AccuracyService` |
| Screen view and observable model | `App/Sources/Screens/ExportView.swift`, `ExportModel.swift` |
| Path strings for FileManager | `url.fileSystemPath` (`Files/URL+FileSystemPath.swift`), never `url.path()` |
| y-up to z-up before saving | `Mesh.convertedFromYUp()` (`Geometry/AxisConversion.swift`) |

## Testing

Summarised here, detailed in `docs/TESTING.md`:

- Every new public Core function gets a test (Swift Testing).
- Every bug fix gets a regression test that fails without the fix.
- Core line coverage stays at 80% or more (`scripts/check-coverage.sh`).
- Sensor-dependent changes get items in an on-device checklist in `docs/checklists/`.

## Git Conventions

- **Branches:** short-lived, named by the Bolt or fix slug (for example
  `sweep-capture`, `fix-file-paths`, `docs-fill`), branched from `main`. Never commit to
  `main` directly.
- **Commits:** `<slug>: <what it does>` in the imperative, for example
  `fix-file-paths: find scans in folders whose names have spaces`. Bolts add the Bolt
  number: `scan-library: Bolt 5 — scan library and scan detail`. The body explains the
  why. Agent commits end with a `Co-Authored-By:` line.
- **Merging:** each Bolt is squash-merged into `main` as one commit named by its slug.
- **Pull requests:** not documented beyond the above; the history shows Bolts merged as
  single squash commits.

## Architecture Boundaries

The import rules from `docs/ARCHITECTURE.md`, restated as things a reviewer checks:

| Layer | May import | Must not import |
|---|---|---|
| `Packages/ScanLabCore` | Foundation | ARKit, RealityKit, SceneKit, UIKit, SwiftUI, AVFoundation, Metal, Vision, ModelIO, OSLog; anything in `App/` |
| App adapters | ScanLabCore, Apple frameworks | Screens and screen models |
| App screens and models | ScanLabCore, SwiftUI, UIKit, Observation | Concrete adapter types (use the port from `AppEnvironment`); the photo screen's direct use of `ObjectCaptureSession` is the one recorded exception (ADR-022) |
| `AppEnvironment` | Everything in App | — |

## Before Submitting

- [ ] Pushed, and the CI run is green (SwiftLint `--strict`, swift-format `--strict`,
      Core tests, 80% coverage, unsigned app compile)
- [ ] Tests pass, and new behaviour has new tests
- [ ] New behaviour is visible in the diagnostics log
- [ ] No console output, no `url.path()`
- [ ] Sensor-dependent change: on-device checklist written or updated
- [ ] Docs updated if the change alters a documented interface or decision
