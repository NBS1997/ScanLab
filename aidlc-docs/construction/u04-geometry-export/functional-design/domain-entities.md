# Domain Entities — U04 Geometry and Mesh Export

Inputs: `components.md`, `component-methods.md` (Geometry, MeshSimplifier, MeshFiles, Units), `decisions.md` (ADR-003, ADR-013), `business-rules.md`.

All entities are value types in Core (Foundation only, `Sendable`).

| Entity | Holds | Notes |
|---|---|---|
| `Vec3` | x, y, z as `Double` | `Double` rather than `Float`: quadric sums and mm conversion keep precision well beyond 0.1%; costs about 2.4 MB extra at 200,000 faces. STL converts to `Float` when writing. |
| `Box` | minimum, maximum | Overall size; `size`, `centre`, `diagonal`. |
| `Transform` | 3 × 3 rows and a translation | `scaling(by:)`, `moving(by:)`; a mirroring transform flips faces. |
| `Triangle` | three vertex indices | Anticlockwise seen from outside. |
| `Mesh` | vertices (metres), triangles | Throwing initialiser checks indices and finite positions (`MeshError`). `faceCount`, `boundingBox` (used vertices only), `volume`, `surfaceArea`, `openEdgeCount`, `transformed(by:)`, `scaled(by:)`, `compacted()`. |
| `ExportDetail` | `.full`, `.fusionFriendly`, `.light` | `faceLimit` nil / 10,000 / 5,000; `targetFaces(for:)`, `prepare(_:)`. |
| `MeshFormat` | `.stl`, `.obj` | Extension and display name. |
| `FileUnit` | `.metres`, `.millimetres` | For reading OBJ files. |
| `MeshFileError` | `noSpace`, `writeFailed`, `readFailed`, `malformed(line:reason:)`, `tooLarge` | Messages give reason and next step. |
| `SimplifyError` | `invalidTarget`, `cannotReach(target:reached:)` | |

## Sample mesh

`SampleMeshes.stepBlock()`: a closed stepped block with a round boss, 60 × 40 × 20 mm
overall (base 60 × 40 × 10, a step 20 mm long rising to 15 mm, a boss 16 mm across
rising to 20 mm). 310 coarse faces; three midpoint subdivisions give 19,840 faces.

## Relationships

```
Mesh --ExportDetail.prepare--> MeshSimplifier --> Mesh (<= limit)
Mesh --MeshFiles (x1000)--> STL / OBJ bytes in millimetres --> temporary file --> save chooser
```

Text fallback: a mesh is reduced to the chosen level by the simplifier, converted to
millimetre file bytes, written to a temporary file and handed to the save chooser.
