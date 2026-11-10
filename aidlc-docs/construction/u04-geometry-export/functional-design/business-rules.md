# Business Rules — U04 Geometry and Mesh Export

Inputs: `unit-of-work.md` (U04), `requirements.md` (FR-6.4, FR-7.1–7.4, NFR-9, PC2), `decisions.md` (ADR-003, ADR-008, ADR-013), `bolt-plan.md` (Bolt 3), `mockups.md` and `interaction-spec.md` (Export).

| ID | Rule | Source | Enforced by |
|---|---|---|---|
| GE-1 | Meshes are held in metres; exported files are in millimetres (every position × 1,000). | FR-7.2, ADR-013 | `MeshFiles` |
| GE-2 | Three detail levels: Full (every face), Fusion-friendly (at most 10,000 faces), Light (at most 5,000). A mesh already within a limit is exported unchanged. | FR-7.3, PC2 | `ExportDetail`, `MeshSimplifier` |
| GE-3 | Simplification never exceeds the target. If no further merge is safe, it fails with `cannotReach` instead of returning more faces. Negative targets are refused. | component-methods.md | `MeshSimplifier` |
| GE-4 | Simplification never tears or folds the surface: merges that break the link condition, duplicate a face, or turn a face by more than about 78° are skipped. A closed mesh stays closed. | FR-7.3 (converts to a solid) | `CollapseChecks` |
| GE-5 | Simplification is deterministic: the same mesh and target always give the same result. | Testability | `EdgeHeap` tie-breaking |
| GE-6 | Binary STL is exactly 84 + 50 × faces bytes, little-endian, with a header that does not start with "solid". | STL format | `MeshFiles.stlData` |
| GE-7 | OBJ numbers have at most four decimals (0.1 µm), use "." whatever the phone's region, and never use exponents. | FR-7.1 (opens everywhere) | `MeshFiles.formatNumber` |
| GE-8 | OBJ reading accepts quads and larger faces (fan-triangulated), `v/t/n` corners and negative indices; any unreadable line fails with its line number. | U08 needs | `OBJParser` |
| GE-9 | A file appears complete or not at all. When free space is known to be short, the export fails before writing; a full storage during writing is reported as "not enough free space". | NFR-9 | `MeshFiles.write`, `ExportService` |
| GE-10 | Every export asks where to save, using the phone's own chooser. | FR-7.4 | `DocumentExportPicker` |
| GE-11 | Lengths show in millimetres to 0.1 mm, or metres to 1 mm once any dimension would show as 1,000.0 mm or more; Australian number format. | FR-6.4, Q6-B | `Units` |
| GE-12 | Every export step and failure is logged (category `export`): opened, levels ready (faces per level, time), file written (bytes, time), saved or cancelled, failures with reason. | Project rule, FR-10.1 | `ExportService`, `ExportModel` |
| GE-13 | Errors stay on the Export screen with reason and next step until the next attempt. | Mockups Q3-A | `ExportView` |
