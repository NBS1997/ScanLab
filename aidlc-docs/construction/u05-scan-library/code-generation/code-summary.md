# Code Summary — Bolt 5 (Scan Library, U05)

Inputs: U05 functional design (`business-rules.md`, `domain-entities.md`, `frontend-components.md`), `bolt-plan.md` (Bolt 5), `requirements.md` (FR-6.1–6.4, FR-6.6, NFR-8, NFR-9), `stories.md` (US-10), `component-methods.md`, `services.md`, `decisions.md` (ADR-003, ADR-007, ADR-011), `mockups.md`, `interaction-spec.md`.

## What Was Built

| Area | Files | Notes |
|---|---|---|
| Core | `Packages/ScanLabCore/Sources/ScanLabCore/Library/` | `Scan` manifest and `CaptureMethod`; `ManifestCodec` (tolerant JSON); `StoreError`, `StorageUse`, `ScanStoring` port, `MemoryScanStore`; `ScanLibrary` actor; `ScanNaming`; `MeshBinary`; `ThumbnailRenderer`; `ViewerGeometry`. `Units.storage` added. |
| Core tests | 5 new test files | 212 tests in 30 suites; Core line coverage 99.2% (CI run 42828255196) |
| Adapter | `App/Sources/Library/FileScanStore.swift` | Folder per scan, staged `.incoming-…` folder renamed into place, atomic manifest replace, sizes from resource values, free space from `volumeAvailableCapacityForImportantUsage`, PNG thumbnails |
| Screens | `LibraryView`, `LibraryModel`, `ScanDetailView`, `ScanDetailModel`, `ModelView` | List with thumbnails, swipe delete, context-menu rename, pull to refresh; detail with SceneKit model, chips, details, Check accuracy (disabled) and Export |
| Wiring | `AppEnvironment.swift`, `DiagnosticsView/Model.swift` | `library` in the composition root; "Add sample to library" |
| Checklist | `docs/checklists/bolt-05-scan-library.md` | |

## Deviations From the Design

- `ScanStoring` is synchronous and byte-based (`scanIDs`, `manifestData`, `meshData`,
  `thumbnailData`, `create`, `replaceManifest`, `remove`, `storage`) instead of
  `list/read/write/size/rawCaptureURL`. The actor then gives a true single writer, and
  decoding is tested in Core. `rawCaptureURL` and `keepRawCapture` wait for U08;
  `attach(report:to:)` waits for U10.
- `all()` returns `ScanListing` (scans plus an unreadable count), not `[Scan]`.
- `add` takes an optional `name:` as well as `mesh:method:detail:`.
- Free space is checked through an `availableBytes` closure given to `ScanLibrary`.
- No "New scan" button on Library yet (capture arrives in Bolts 6–7).
- Models are assumed z-up (SL-13); U07 must save z-up meshes.

## Not Verified

- Everything on the phone: thumbnails, list, SceneKit view (turn, zoom, reset, 200,000
  faces), rename and delete flows, sizes shown, sideways layout, VoiceOver, large text.
  Covered by the checklist.
- Scans surviving a TestFlight update (FR-6.3): checked on the build after this one.
- Crash safety of the staged write was reasoned, not tested by killing the app.
- Running out of space on a real phone.
- Compiler warnings in the app build (CI shows only the last 40 lines).
