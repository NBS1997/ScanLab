# Domain Entities — U05 Scan Library

Inputs: `component-methods.md` (ScanLibrary, ScanStoring), `decisions.md` (ADR-007), `unit-of-work-dependency.md`, `requirements.md` (FR-6.1–6.4, FR-6.6).

| Entity | Fields | Notes |
|---|---|---|
| `Scan` (manifest) | `version`, `id` (UUID), `name`, `method`, `createdAt` (whole seconds), `detailLevel?`, `faceCount`, `size?` (metres, `[x, y, z]`), `isReference`, `hasAccuracyReport`, `rawCaptureBytes?` | JSON, ISO 8601 dates, sorted keys. Tolerant decoding (SL-9). |
| `CaptureMethod` | `sweep`, `photos`, `sample` | `displayName`: Sweep, Photos, Sample. |
| `StorageUse` | `modelBytes`, `rawCaptureBytes`, `totalBytes` | Model = folder minus `RawCapture/`. |
| `ScanListing` | `scans` (newest first), `unreadable` | Result of `ScanLibrary.all()`. |
| `StoreError` | `notFound(id)`, `noSpace`, `emptyName`, `nameTooLong(maximum:)`, `writeFailed`, `readFailed`, `corrupt` | Each has a reason-and-next-step description. |
| `MeshBinary` file | magic `SLMESH01`, vertex count, face count, vertices (3 × Float64), faces (3 × UInt32); little-endian | 16 + 24V + 12F bytes. |
| `ViewerGeometry` | `positions`, `normals` (Float, three corners per face, centred), `radius` | Input to the 3D view. |
| `ThumbnailRenderer` | size (160), background, surface, placeholder colours | Orthographic three-quarter view, z-buffer, Lambert shading. |

## Ports and Services

| Name | Kind | Methods |
|---|---|---|
| `ScanStoring` | Port (Core) | `scanIDs()`, `manifestData(for:)`, `meshData(for:)`, `thumbnailData(for:)`, `create(_:manifest:mesh:thumbnail:)`, `replaceManifest(_:for:)`, `remove(_:)`, `storage(for:)` |
| `MemoryScanStore` | Adapter (Core, tests and previews) | Can be told to fail writes |
| `FileScanStore` | Adapter (App) | Folders in Application Support/Scans; `availableCapacity()` |
| `ScanLibrary` | Actor (LibraryService) | `all()`, `scan(_:)`, `mesh(for:)`, `thumbnail(for:)`, `add(mesh:method:detail:name:)`, `rename(_:to:)`, `delete(_:)`, `storage(for:)`, `setReference(_:_:)` |

## For Later Units

- **U07/U08** call `add(mesh:method:detail:)`; U08 will add a raw-capture location
  (`RawCapture/` inside the scan folder, already counted by `storage(for:)`) and
  `keepRawCapture(_:keep:)`.
- **U10** uses `setReference(_:_:)` and will add `attach(report:to:)`, setting
  `hasAccuracyReport`.
