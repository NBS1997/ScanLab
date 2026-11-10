# Code Summary — Bolt 1 (Walking Skeleton)

Inputs: `code-generation-plan.md`, the U01 and U02 design records, `bolt-plan.md`.

## What Was Built

| Area | Files | Notes |
|---|---|---|
| Core package | `Packages/ScanLabCore` | Foundation only. `LogEvent`, `Logging` port, `MemoryLog`, `LogCodec` (JSON lines, tolerant decoding), `LogTrimmer` (5,000 lines), `LogFormatter`, `BuildInfo` (90-day expiry) |
| Core tests | 26 tests in 5 suites | 97.7% line coverage of Core (CI run 42807111212) |
| App | `App/Sources` | `ScanLabApp` (logs launch), `AppEnvironment` (composition root), `FileLog` (ordered queue, actor-owned file, flush per event, trim at launch, reports failed writes), `LibraryView` (empty state), `DiagnosticsView` and `DiagnosticsModel` (build info, activity, export) |
| Project | `project.yml` | iOS 26.0, Swift 6, bundle `com.nbs1997.scanlab`, build-date stamp script, camera purpose and encryption declaration |
| CI | `.github/workflows/ci.yml` | Signing-material check, SwiftLint (with a console-output ban), swift-format, tests, 80% coverage gate, unsigned device compile |
| Delivery | `builder.json`, `ios-build.yml` | builder-managed; signing secrets in the repository's secret store |

## Deviations From the Design

- **Delivery** changed from in-GitHub to builder-from-PC (ADR-016, owner's decision).
- **Framework fix:** `.claude/tools/aidlc-bolt.ts` used a URL path that fails on Windows;
  changed to `fileURLToPath`. Needed for any Bolt to start on this machine.
- **Export logging:** the export file is prepared when Diagnostics opens; the log records
  when Export log is tapped rather than each preparation, to avoid an entry per visit.

## Issues Found and Fixed in CI

1. `.gitignore` pattern `build/` matched the Core `Build/` source folder on Windows
   (case-insensitive) — narrowed to `/build/`.
2. SwiftLint `optional_data_string_conversion` in `LogCodec` — switched to the failable
   conversion with an error.
3. Coverage script not executable in Git — mode fixed and called through `bash`.

## Not Verified

- Anything on the phone: launch, file log persistence across force-quit, build-date
  stamping in a Release archive, share sheet, orientation and accessibility. Covered by
  the on-device checklist.
