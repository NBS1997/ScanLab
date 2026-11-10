# Code Summary — U03 Reference Object (Bolt 2, `reference-object`)

Inputs: `unit-of-work.md` (U03), `bolt-plan.md` (Bolt 2), `requirements.md` (FR-8.1–8.5), `decisions.md` (ADR-009, ADR-010), `stories.md` (US-12), `functional-design/business-rules.md`, `functional-design/domain-entities.md`.

## What was built

| File | Purpose |
|---|---|
| `reference-object/reference_object.py` | CadQuery 2.5.2 script: builds the solid and writes the four outputs |
| `reference-object/test_reference_object.py` | 43 pytest checks (BR-2 to BR-9), plain-Python STL parsing |
| `reference-object/output/reference-object.stl` | Binary STL, mm, 0.01 mm chord tolerance |
| `reference-object/output/reference-object.step` | STEP for Fusion |
| `reference-object/output/feature-table.json` | Feature table, version 1, 26 features |
| `reference-object/output/measurement-sheet.md` | Caliper sheet with print guidance |
| `reference-object/README.md` | What it is, printing, regenerating, how the table is used |
| `.github/workflows/reference-object.yml` | Runs the script and checks on ubuntu-latest, Python 3.12; uploads `reference-object-output` |
| `.gitattributes` | `*.stl binary` added |

The object is 159.3 × 105 × 108 mm (volume about 215 cm³): an 8 mm plate with a lopsided
outline (30° corner cut, 10° slanted back, R 150 curved left side), a 100 mm tower with
one rounded edge, two-step stairs with a chamfer, a 25° ramp, a half-ball dome, a pad, a
thin rib, a slot, four through holes and four round posts.

| Kind | Count | Smallest | Largest |
|---|---|---|---|
| Length | 6 | 1.6 mm | 108 mm |
| Step | 5 | 1.5 mm | 100 mm |
| Hole | 4 | 2 mm | 30 mm |
| Boss | 4 | 2 mm | 40 mm |
| Angle | 4 | 45° on a 1.7 mm face | 80° on a 101.5 mm face |
| Curve | 3 | R 1.5 mm | R 150 mm |

## Deviations from the brief

- The feature table adds `sizeMm` and `sizeClass` to each feature (angles need a size in
  mm for FR-8.2 and the report groups by size class, FR-9.6), plus top-level
  `coordinateFrame`, `angleConvention`, `sizeClasses` and `volumeMm3`.
- `units` is an object (`{length: "mm", angle: "deg"}`) rather than one string, because
  the table holds both.
- Holes stop at 30 mm and bosses at 40 mm (reason in the README).
- Generated outputs are downloaded from CI and committed by hand; the workflow has
  read-only permissions and never pushes.

## Not verified

- Not printed, not loaded in a slicer, and not opened in Fusion. The STEP file is only
  checked by re-importing it with CadQuery at the same volume.
- The caliper instructions have not been tried by the owner. Some features cannot be
  measured with calipers alone: C1 needs a radius gauge, A2 and A4 a protractor, A1 is
  marginal, and S5 and C3 are worked out from other readings.
- The STEP header carries a timestamp, so the STEP (and possibly STL header) bytes change
  on every run; the feature table and sheet are byte-identical between runs.
- Whether the 2 mm hole and 2 mm post print cleanly depends on the printer; that is part
  of what is being measured.
