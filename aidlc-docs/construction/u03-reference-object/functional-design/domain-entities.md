# Domain Entities — U03 Reference Object

Inputs: `unit-of-work.md` (U03), `bolt-plan.md` (Bolt 2), `requirements.md` (FR-8.1–8.5), `decisions.md` (ADR-009, ADR-010), `stories.md` (US-12).

The feature table (`reference-object/output/feature-table.json`) is the contract with the
app (bundled by U10, used by U11). Coordinates are object coordinates in millimetres: X
along the straight front edge, Y towards the back, Z up from the underside (Z = 0).

## FeatureTable

| Field | Type | Rule |
|---|---|---|
| `version` | Integer | Increases whenever the geometry changes; measurements are tied to a version |
| `units` | `{length: "mm", angle: "deg"}` | Fixed |
| `coordinateFrame` | String | Plain description of the axes |
| `angleConvention` | String | Angles are the acute angle between the two faces' planes |
| `sizeClasses` | `{small: 5, medium: 30, large: null}` | Upper bound in mm of each class (`null` = no bound) |
| `overall` | `{min, max, size}` | Axis-aligned box of the whole object, mm |
| `volumeMm3` | Number | Solid volume, for sanity checks |
| `features` | [Feature] | In ID order within kind: L, S, H, B, A, C |

## Feature

| Field | Type | Rule |
|---|---|---|
| `id` | String | Kind letter + number (`L1`, `S2`, `H3`, `B1`, `A2`, `C1`); unique |
| `kind` | `length` · `step` · `hole` · `boss` · `angle` · `curve` | |
| `description` | String | What the feature is, in plain words |
| `designValue` | Number | mm for all kinds except `angle` (deg); holes and bosses are diameters, curves are radii |
| `unit` | `mm` · `deg` | `deg` only for `angle` |
| `sizeMm` | Number | Characteristic size: the design value in mm, or for an angle the length of the angled face |
| `sizeClass` | `small` · `medium` · `large` | From `sizeMm` and `sizeClasses` |
| `measure` | String | Plain-English caliper instruction, printed on the sheet |
| `region` | `{min:[x,y,z], max:[x,y,z]}` | Box around the feature's surfaces (or a nearby patch of very large faces), grown by 0.25 mm and clipped to `overall` |
| `primitive` | `plane-pair` · `plane-angle` · `cylinder` · `sphere` | Shape to fit to scan points in the region: lengths and steps use `plane-pair`; angles `plane-angle`; holes, bosses, C1 and C3 `cylinder`; C2 `sphere` |

## Measured value (later, U10)

The owner's caliper reading per feature ID and table version (FR-8.6) is stored by the
app, not here. A blank reading means the feature is left out of the report.
