# Business Rules — U05 Scan Library

Inputs: `unit-of-work.md` (U05), `unit-of-work-dependency.md` (U07/U08/U10 integration points), `requirements.md` (FR-6.1–6.4, FR-6.6, NFR-8, NFR-9), `stories.md` (US-10), `component-methods.md` (ScanLibrary, ScanStoring), `services.md` (LibraryService), `decisions.md` (ADR-003, ADR-007, ADR-011), `bolt-plan.md` (Bolt 5), `mockups.md`, `interaction-spec.md`, `accessibility-checklist.md`.

| ID | Rule | Source | Enforced by |
|---|---|---|---|
| SL-1 | Each scan is one folder in Application Support/Scans, named by its identity, holding `manifest.json`, `mesh.slmesh`, `thumbnail.png` and, when kept, `RawCapture/`. No database. | ADR-007 | `FileScanStore` |
| SL-2 | A new scan is written into a hidden `.incoming-…` folder and renamed into place only when complete, so a crash leaves the scan whole or absent. Leftover `.incoming-…` folders are removed (and logged) on the next listing. Manifest changes replace the file in one step. | NFR-8 | `FileScanStore.create`, `replaceManifest` |
| SL-3 | Names are trimmed of spaces and line breaks, must not be empty, and are at most 80 characters. A refused name leaves the old one in place. | FR-6.2 | `ScanNaming.validated` |
| SL-4 | A new scan's default name is its method and when it was made, in Australian English and 24-hour time: "Sweep 11 Nov 14:05". Names need not be unique. | FR-6.1 | `ScanNaming.defaultName` |
| SL-5 | The list is newest first; equal dates are ordered by identity so the order never jumps. | FR-6.1 | `ScanLibrary.all` |
| SL-6 | Delete asks first, naming the scan, what is lost (model, and raw capture if kept) and the storage freed. Deleting removes the whole folder. | FR-6.2, interaction-spec (Destructive Actions) | `ScanText.deleteMessage`, `ScanLibrary.delete` |
| SL-7 | Before writing a scan, free space is checked against the model and manifest size plus 2 MB spare. When short, nothing is written and the reason is shown ("not enough free space … nothing was saved"). A full storage found during the write is reported the same way. | NFR-9 | `ScanLibrary.add`, `FileScanStore.classify` |
| SL-8 | A scan whose manifest is missing, damaged or belongs to another folder is skipped and counted, never stopping the list. The folder is left on the phone; the screen says how many were skipped. | NFR-8 | `ScanLibrary.all`, `LibraryView` |
| SL-9 | Manifests are read forgivingly: unknown fields are ignored and missing optional fields take defaults, so scans survive app updates (FR-6.3). Only identity, name, method and date are required. | FR-6.3 | `Scan.init(from:)` |
| SL-10 | The model is stored exactly (8-byte numbers) and read back bit for bit. A cut-short or foreign file is reported as damaged. | NFR-8 | `MeshBinary` |
| SL-11 | Check accuracy is shown on Scan detail but disabled with the reason "Comes with the accuracy report". In unit U10 it will need a scan marked as the reference (`isReference`). | Mockups screen 4, U10 integration point | `ScanDetailModel.canCheckAccuracy` |
| SL-12 | Edges is shown on Scan detail but disabled: "Coming in a later build" (unit U12). | FR-6.5 (later) | `ScanDetailView` |
| SL-13 | Models are taken to have z pointing up (as the sample and the exports). Capture units must save z-up models, or the thumbnail and the 3D view show them on their side. | Consistency with ADR-013 exports | `ThumbnailRenderer`, `ModelView` |
| SL-14 | Every library change and failure is logged under `library`: scan added (method, faces, bytes, time), renamed, deleted (bytes freed), reference mark changed, scan skipped, not enough space, unfinished scan removed, and each failure with its reason. Screens log `Library shown` and `Scan detail shown`. Names are not logged, only their length. | Project rule, ADR-011 | `ScanLibrary`, `FileScanStore`, screen models |
| SL-15 | Only `ScanLibrary` (an actor) calls the store, so there is a single writer and changes never interleave. | services.md | `ScanLibrary` |

## Decisions Made in This Unit

- **Stored model format: our own binary layout (`MeshBinary`), not OBJ.** Exact round
  trip (OBJ keeps four decimals; STL keeps 4-byte numbers), about a third of OBJ's size
  (24 bytes per point, 12 per face: 4.8 MB for 200,000 faces), no text parsing, and
  truncation is detected from the header counts. Exports still use STL/OBJ.
- **3D view: SceneKit `SCNView`.** Built-in turn, zoom and move with no gesture code,
  automatic lighting, easily handles 200,000 faces. RealityKit was considered: newer,
  but its non-AR camera controls on iPhone need more setup that could not be tried
  without a Mac. SceneKit no longer gains features, so the view is isolated in
  `ModelView` for an easy swap.
- **The store port is synchronous** and deals in bytes; Core turns bytes into scans and
  models, so all of that is tested on the build machine.
