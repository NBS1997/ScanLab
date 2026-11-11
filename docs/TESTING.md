# LidarApp — Testing Strategy

Testing is split by what can run without the phone (team practice, ADR-003).
Sensor-independent logic lives in `ScanLabCore` and is tested automatically in every CI
run. Sensor-dependent behaviour cannot run in CI, so it is checked by the owner on the
phone from a written checklist.

There is no Mac and no local Swift toolchain. **Tests only run on GitHub's macOS runner**
(`.github/workflows/ci.yml`), on every push and pull request. Push the branch and read
the run; a change with a failing run is not finished.

## Tiers

| Tier | Covers | Lives in | Run with |
|---|---|---|---|
| Core unit tests | Geometry, simplification, STL/OBJ writing and reading, SLMESH01, scan library and manifests, capture state machines, mesh assembly, sensor maths (colour maps, centre sampler, frame-rate meter, overlays, close range, depth quality), photo import and raw-capture files, the log model, build info, units, and the accuracy pipeline | `Packages/ScanLabCore/Tests/ScanLabCoreTests/` | `swift test --package-path Packages/ScanLabCore --enable-code-coverage` (CI step "Core tests with coverage") |
| Coverage gate | At least 80% line coverage of `Sources/ScanLabCore/` (tests excluded) | `scripts/check-coverage.sh` | `bash scripts/check-coverage.sh 80` (CI) |
| App compile | The App target, including all adapters and screens, compiles for a device | `App/Sources`, `project.yml` | `xcodegen generate` then unsigned `xcodebuild … build` (CI) |
| Reference object | The CadQuery script's outputs (pytest checks) | `reference-object/test_reference_object.py` | `reference-object.yml` workflow, on changes under `reference-object/` |
| On-device checklist | Anything that needs the camera, LiDAR, ARKit, Object Capture, the save chooser, VoiceOver, layout and real storage | `docs/checklists/bolt-NN-<slug>.md` | The owner, on the phone, after `builder ios release` delivers the build to TestFlight |

There are no App-target unit tests and no UI tests: App code is either thin adapters
(untestable off the phone) or SwiftUI screens. Logic that needs a test belongs in Core.

The accuracy proof required by the requirements (synthetic scans with known error) is in
`AlignmentTests` (0.2 mm offset, 0.25 mm noise, arbitrary pose, background, the real
reference STL) and `DeviationTests` (per-size-class errors). Several accuracy and
reference tests read `reference-object/output/` from the repository through
`AccuracyFixtures.repositoryFile`, so those committed outputs are test inputs.

## When Tests Are Required

The rules that matter. These are checked in review:

- **Every new public Core function** gets a test covering its contract.
- **Every bug fix** gets a regression test that fails without the fix (`AGENTS.md`,
  rule 3). Write the test first, watch it fail in CI, then fix. Example:
  `FileSystemPathTests` reproduces the build 4 "%20" bug with a real folder named
  "Application Support".
- **Every refactor** is preceded by a characterisation test if none exists, so the
  refactor can be shown not to change behaviour.
- **Every delivery that changes sensor-dependent behaviour** carries an on-device
  checklist in `docs/checklists/` (project rule). Each item says what to do and what
  should be seen; the owner exports the diagnostics log when something fails.

## Test Quality

- Test **behaviour** — inputs to outputs. Not implementation details.
- Fake at the ports only. Core ships `MemoryLog` and `MemoryScanStore` for this, and
  tests use fake capture ports (for example in `SweepCaptureServiceTests`). Mocking
  internal call order couples the test to the code's shape.
- Don't assert that a function was called. Assert the observable outcome — the saved
  scan, the logged event, the returned error.
- Name tests as sentences describing the expected behaviour:
  `@Test("keeps spaces as spaces, so FileManager finds the folder")`.
- **Keep tests fast.** The whole suite ran in about 13 seconds at Bolt 8. A simplifier
  that went quadratic once made the large-mesh test exceed its time limit and fail CI
  (ADR-026). Expensive results, such as sample simplifications, are computed once per
  run and shared; the one deliberately large test (`SimplifierTests`, "a large mesh
  simplifies in reasonable time") has a `.timeLimit(.minutes(3))`. Use synthetic shapes
  of the smallest size that proves the point.

## Conventions

- **Framework:** Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`,
  `#require`), with `@testable import ScanLabCore`. No XCTest.
- **Location:** one flat folder, `Packages/ScanLabCore/Tests/ScanLabCoreTests/`. It does
  not mirror the source tree's subfolders.
- **Naming:** `<Subject>Tests.swift`, containing a `@Suite("<plain description>")`
  struct, for example `MeshBinaryTests.swift`, `AlignmentTests.swift`.
- **Fixtures:** shared builders live in `TestMeshes.swift` (meshes, temporary folders)
  and `AccuracyFixtures.swift` (a stand-in reference object, known transforms, scans with
  exact errors, the real STL). Everything is in metres unless a name says otherwise.
- **Isolation:** each test that touches disk makes its own folder with
  `TestMeshes.temporaryFolder()` (a unique `ScanLabTests-<uuid>` folder), so tests never
  share files. `TestMeshes.cleanUp(_:)` removes it; not every test calls it yet. Tests that pass only in a particular order are broken tests.
- **Determinism:** randomness uses fixed seeds, as the accuracy pipeline does, so a
  failure reproduces on the next run.

## Running

There is no local toolchain, so "running" means pushing a branch and reading CI:

```bash
git push -u origin <branch>
gh run list --repo NBS1997/ScanLab --branch <branch>
gh run watch <run-id> --repo NBS1997/ScanLab --exit-status
```

The CI steps, for reference (on a machine with Xcode 26):

```bash
swift test --package-path Packages/ScanLabCore --enable-code-coverage   # full Core suite
swift test --package-path Packages/ScanLabCore --filter MeshBinaryTests # one suite
bash scripts/check-coverage.sh 80                                       # coverage floor
```

The coverage script prints a per-file table, then the overall figure; CI fails below
80%. Core has stayed around 98–99% through Bolt 8.

## If a test fails

Fix the implementation, not the test. If a test is genuinely wrong, explain why before
changing it — "the test was wrong" is the most common cover story for a real bug. CI
shows only the last 40 lines of the app build, so compiler warnings in the App target
are not visible there.
