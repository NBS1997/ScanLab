# Reference object

A purpose-made object to 3D print, measure with calipers and then scan, so ScanLab has a
known truth to compare scans with (US-12, FR-8.1–8.5, ADR-010).

Everything here comes from one parametric script, `reference_object.py`. It writes:

| File | What it is for |
|---|---|
| `output/reference-object.stl` | Load this in the slicer and print it. Millimetres. |
| `output/reference-object.step` | Open this in Autodesk Fusion (File > Open, or Insert). |
| `output/feature-table.json` | The feature table the app will bundle (U10, U11). |
| `output/measurement-sheet.md` | Print this and fill in your caliper readings. |

The generated files are committed, so you never need to run the script yourself.

## The object

About 159 × 105 mm on the bed and 108 mm tall at its tallest point (the tower). Hold it
with the **long straight edge towards you**: the tall tower is at the back left, the
stairs at the front right, and the left side curves gently outwards. It looks different
from every side and from above and below, so a scan can only be matched to it one way
round (FR-8.3).

It has 26 measurable features, each with an ID:

| Kind | IDs | Sizes |
|---|---|---|
| Lengths between faces | L1–L6 | 1.6, 6, 22, 26, 105, 108 mm |
| Steps and heights | S1–S5 | 1.5, 8, 10, 15, 100 mm |
| Holes | H1–H4 | 2, 5, 12, 30 mm diameter |
| Round posts (bosses) | B1–B4 | 2, 8, 20, 40 mm diameter |
| Angles between faces | A1–A4 | 45°, 30°, 25°, 80° on faces 1.7, 25.4, 33.1, 101.5 mm long |
| Curved surfaces | C1–C3 | 1.5, 15, 150 mm radius |

**Why holes and posts stop at 30–40 mm, not 100 mm.** A 100 mm hole or post would not
fit on a plate this size alongside everything else. Making the plate big enough would
roughly double the print time and the size of the scan, which is what this object is
meant to keep small. Large-scale curvature is covered instead by the R 150 curved left
side (C3), and large distances by L5, L6, S5 and A4.

## How to print it

- Matt, light-coloured filament (white or light grey matt PLA). Shiny or dark plastic
  confuses the depth sensor.
- Flat on the bed, underside down, exactly as the STL is laid out. No supports: nothing
  overhangs more than 45 degrees, and every hole and post stands upright.
- 0.2 mm layers, 3 walls, 15–20% infill. The thinnest wall is the 1.6 mm rib (L1).
- Turn off slicer hole compensation and "elephant foot" correction so the print shows
  the printer's natural error, which is what you then measure.

Then follow `output/measurement-sheet.md`. **Your caliper value, not the design value, is
the truth** the app compares scans with. The design value is only a check that you have
measured the right thing.

## How the feature table is used

`feature-table.json` lists every feature with:

- `id`, `kind` (`length`, `step`, `hole`, `boss`, `angle`, `curve`) and a `description`;
- `designValue` and `unit` (`mm`, or `deg` for angles: the acute angle between the two
  faces' planes);
- `sizeMm` and `sizeClass` (`small` up to 5 mm, `medium` up to 30 mm, `large` above), used
  to group errors by size in the accuracy report (FR-9.6);
- `measure`, the plain-English caliper instruction printed on the sheet;
- `region`, a box `{min:[x,y,z], max:[x,y,z]}` in millimetres in object coordinates
  around the surfaces that make up the feature;
- `primitive`, the shape to fit to the scan inside that region: `plane-pair` (distance
  between two parallel flat faces), `plane-angle`, `cylinder` or `sphere`.

The app aligns a scan to the object's shape, then fits each feature's primitive to the
scan points inside its region and compares the result with your caliper value (ADR-009).
`version` changes whenever the object changes, so measurements taken on an old print are
never compared against a new design.

Object coordinates: X along the front edge (left to right), Y from the front edge to the
back, Z up from the underside, which is Z = 0.

## How to regenerate

Only needed if you change the design. Edit the numbers at the top of
`reference_object.py`, then either:

- **On GitHub (no install):** push the change. The *Reference object* workflow
  (`.github/workflows/reference-object.yml`) installs CadQuery, runs the script and the
  checks, and uploads the four files as the `reference-object-output` artifact. Download
  it (`gh run download <run-id> -n reference-object-output -D reference-object/output`)
  and commit the files.
- **Locally:** install CadQuery 2.5.2 and pytest in Python 3.12, then run
  `python reference-object/reference_object.py` and
  `python -m pytest reference-object/test_reference_object.py -v`.

If you change the object, increase `TABLE_VERSION` and reprint before measuring again.

The checks (`test_reference_object.py`) confirm: it fits the 340 × 320 × 340 mm printer;
every kind has three or more sizes, the smallest 2 mm or under and the largest 100 mm or
over (30 mm for holes and posts); IDs are unique; every region sits inside the object's
box and really contains a face of the stated size, radius or angle; the STL is closed
(every edge shared by exactly two triangles); nothing overhangs more than 45 degrees; the
shape has no mirror or half-turn symmetry; the STEP file reopens at the same volume; and
two runs give an identical feature table.
