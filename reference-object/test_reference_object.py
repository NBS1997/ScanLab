"""Checks for the reference object (Unit U03). Run after reference_object.py:

    python reference-object/reference_object.py
    python -m pytest reference-object/test_reference_object.py -v

Needs CadQuery 2 and pytest. The STL checks use plain Python (no mesh library).
"""

from __future__ import annotations

import json
import math
import re
import struct
from collections import Counter
from pathlib import Path

import cadquery as cq
import pytest
from OCP.BRepAdaptor import BRepAdaptor_Surface

import reference_object as ro

OUT = ro.OUTPUT_DIR
STL = OUT / "reference-object.stl"
STEP = OUT / "reference-object.step"
TABLE = OUT / "feature-table.json"
SHEET = OUT / "measurement-sheet.md"

KINDS = {"length", "step", "hole", "boss", "angle", "curve"}
PRIMITIVES = {"plane-pair", "cylinder", "sphere", "plane-angle"}
# Holes and bosses cannot reach 100 mm on a ~160 x 105 mm plate (see README); they must
# still reach at least 30 mm so they span small-part to medium scale.
KINDS_CAPPED_BELOW_100 = {"hole": 30.0, "boss": 30.0}

GEOM_TOL = 0.01  # mm or degrees


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def solid() -> cq.Solid:
    return ro.build()


@pytest.fixture(scope="module")
def table() -> dict:
    return json.loads(TABLE.read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def triangles() -> list:
    return read_stl(STL)


# ---------------------------------------------------------------------------
# Plain-Python STL helpers
# ---------------------------------------------------------------------------


def read_stl(path: Path) -> list:
    """Return a list of triangles, each a tuple of three (x, y, z) vertex tuples."""
    data = path.read_bytes()
    if len(data) >= 84:
        (count,) = struct.unpack_from("<I", data, 80)
        if len(data) == 84 + 50 * count:  # binary STL
            tris = []
            for i in range(count):
                vals = struct.unpack_from("<12f", data, 84 + 50 * i)
                tris.append((tuple(vals[3:6]), tuple(vals[6:9]), tuple(vals[9:12])))
            return tris
    text = data.decode("ascii")  # ASCII STL fallback
    verts = [tuple(float(v) for v in m) for m in re.findall(r"vertex\s+(\S+)\s+(\S+)\s+(\S+)", text)]
    return [tuple(verts[i : i + 3]) for i in range(0, len(verts), 3)]


def edge_problems(tris: list) -> tuple[int, int]:
    """Count edges that break a closed, consistently oriented surface.

    Vertices are matched exactly (the exporter writes shared vertices identically).
    In a watertight mesh every edge is used by exactly two triangles, once in each
    direction. Returns (edges not used exactly twice, directed edges used twice the
    same way). Zero-area triangles (a repeated vertex) are ignored.
    """
    directed = Counter()
    for a, b, c in tris:
        if a == b or b == c or a == c:
            continue
        for u, v in ((a, b), (b, c), (c, a)):
            directed[(u, v)] += 1
    undirected = Counter()
    for (u, v), n in directed.items():
        undirected[frozenset((u, v))] += n
    open_edges = sum(1 for n in undirected.values() if n != 2)
    flipped = sum(1 for n in directed.values() if n != 1)
    return open_edges, flipped


def tri_normal(tri) -> tuple[float, float, float] | None:
    a, b, c = tri
    u = [b[i] - a[i] for i in range(3)]
    v = [c[i] - a[i] for i in range(3)]
    n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
    length = math.sqrt(sum(x * x for x in n))
    if length < 1e-12:
        return None
    return tuple(x / length for x in n)


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------


def boxes_touch(bb, region: dict, tol: float = 1e-3) -> bool:
    lo, hi = region["min"], region["max"]
    return (
        bb.xmin <= hi[0] + tol
        and bb.xmax >= lo[0] - tol
        and bb.ymin <= hi[1] + tol
        and bb.ymax >= lo[1] - tol
        and bb.zmin <= hi[2] + tol
        and bb.zmax >= lo[2] - tol
    )


def faces_in(solid: cq.Solid, region: dict, geom: str) -> list:
    return [f for f in solid.Faces() if f.geomType() == geom and boxes_touch(f.BoundingBox(), region)]


def acute_angle(n1, n2) -> float:
    dot = abs(n1.x * n2.x + n1.y * n2.y + n1.z * n2.z)
    return math.degrees(math.acos(min(1.0, dot)))


def symmetric_volume_ratios(shape: cq.Shape) -> dict:
    """Overlap of the shape with each of its 3 mirror images and 3 half-turned copies.

    Any mirror or half-turn symmetry passes through the centre of the bounding box, so
    each copy is made about that centre. A symmetric shape overlaps its copy completely
    (ratio 1.0).
    """
    bb = shape.BoundingBox()
    c = cq.Vector((bb.xmin + bb.xmax) / 2, (bb.ymin + bb.ymax) / 2, (bb.zmin + bb.zmax) / 2)
    copies = {
        "mirror X": shape.mirror("YZ", c),
        "mirror Y": shape.mirror("XZ", c),
        "mirror Z": shape.mirror("XY", c),
        "half turn about X": shape.rotate(c, c + cq.Vector(1, 0, 0), 180),
        "half turn about Y": shape.rotate(c, c + cq.Vector(0, 1, 0), 180),
        "half turn about Z": shape.rotate(c, c + cq.Vector(0, 0, 1), 180),
    }
    vol = shape.Volume()
    return {name: shape.intersect(copy).Volume() / vol for name, copy in copies.items()}


# ---------------------------------------------------------------------------
# Outputs and determinism
# ---------------------------------------------------------------------------


def test_all_outputs_exist():
    for path in (STL, STEP, TABLE, SHEET):
        assert path.is_file() and path.stat().st_size > 0, f"missing output {path.name}"


def test_feature_table_is_deterministic_and_matches_disk(solid, table):
    fresh = json.loads(json.dumps(ro.feature_table(solid)))
    again = json.loads(json.dumps(ro.feature_table(ro.build())))
    assert fresh == again, "two builds gave different feature tables"
    assert fresh == table, "feature-table.json is stale; re-run reference_object.py"


def test_step_reimports_with_same_volume(solid):
    imported = cq.importers.importStep(str(STEP)).val()
    assert imported.Volume() == pytest.approx(solid.Volume(), rel=1e-4)


# ---------------------------------------------------------------------------
# FR-8.1 size
# ---------------------------------------------------------------------------


def test_fits_printer_volume(table):
    size = table["overall"]["size"]
    for s, limit in zip(size, ro.PRINTER_VOLUME):
        assert 0 < s <= limit
    # Brief: roughly 160 x 110 footprint so it prints quickly and scans in one go.
    assert size[0] <= 170 and size[1] <= 120


def test_overall_box_matches_stl(table, triangles):
    xs = [v[0] for t in triangles for v in t]
    ys = [v[1] for t in triangles for v in t]
    zs = [v[2] for t in triangles for v in t]
    o = table["overall"]
    for got, want in zip((min(xs), min(ys), min(zs)), o["min"]):
        assert got == pytest.approx(want, abs=0.05)
    for got, want in zip((max(xs), max(ys), max(zs)), o["max"]):
        assert got == pytest.approx(want, abs=0.05)


# ---------------------------------------------------------------------------
# FR-8.2 / FR-8.4 feature table
# ---------------------------------------------------------------------------


def test_schema(table):
    assert table["version"] == ro.TABLE_VERSION
    assert table["units"] == {"length": "mm", "angle": "deg"}
    for row in table["features"]:
        assert row["kind"] in KINDS
        assert row["primitive"] in PRIMITIVES
        assert row["unit"] == ("deg" if row["kind"] == "angle" else "mm")
        assert isinstance(row["designValue"], (int, float)) and row["designValue"] > 0
        assert row["description"].strip() and len(row["measure"]) > 30
        assert row["sizeClass"] in {"small", "medium", "large"}
        if row["kind"] == "angle":
            assert 0 < row["designValue"] < 90
            assert row["primitive"] == "plane-angle"
        if row["kind"] in ("length", "step"):
            assert row["primitive"] == "plane-pair"


def test_ids_unique_and_prefixed(table):
    ids = [row["id"] for row in table["features"]]
    assert len(ids) == len(set(ids))
    prefix = {"length": "L", "step": "S", "hole": "H", "boss": "B", "angle": "A", "curve": "C"}
    for row in table["features"]:
        assert re.fullmatch(prefix[row["kind"]] + r"\d+", row["id"]), row["id"]


def test_every_kind_at_three_sizes_spanning_small_to_large(table):
    sizes: dict[str, list[float]] = {k: [] for k in KINDS}
    for row in table["features"]:
        sizes[row["kind"]].append(row["sizeMm"])
    for kind, values in sizes.items():
        assert len(set(values)) >= 3, f"{kind}: only {sorted(set(values))}"
        assert min(values) <= 2.0, f"{kind}: smallest is {min(values)} mm"
        floor = KINDS_CAPPED_BELOW_100.get(kind, 100.0)
        assert max(values) >= floor, f"{kind}: largest is {max(values)} mm"
    largest_length = max(r["designValue"] for r in table["features"] if r["kind"] == "length")
    assert largest_length >= 100.0


def test_regions_inside_overall_box(table):
    lo, hi = table["overall"]["min"], table["overall"]["max"]
    for row in table["features"]:
        rmin, rmax = row["region"]["min"], row["region"]["max"]
        for i in range(3):
            assert lo[i] - 1e-6 <= rmin[i] < rmax[i] <= hi[i] + 1e-6, f"{row['id']} region axis {i}"


def test_sheet_lists_every_feature(table):
    sheet = SHEET.read_text(encoding="utf-8")
    for row in table["features"]:
        assert re.search(rf"^\| {row['id']} \|", sheet, re.M), f"{row['id']} missing from sheet"
        assert ro._fmt(row["designValue"], row["unit"]) in sheet
    assert "caliper value" in sheet.lower() and "matt" in sheet.lower()


# ---------------------------------------------------------------------------
# The feature table describes the real geometry
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("fid", [f.id for f in ro.features()])
def test_feature_geometry_matches_design(solid, table, fid):
    row = next(r for r in table["features"] if r["id"] == fid)
    region, value = row["region"], row["designValue"]

    if row["primitive"] in ("cylinder", "sphere"):
        geom = "CYLINDER" if row["primitive"] == "cylinder" else "SPHERE"
        want_r = value / 2 if row["kind"] in ("hole", "boss") else value
        radii = []
        for face in faces_in(solid, region, geom):
            surf = BRepAdaptor_Surface(face.wrapped)
            if geom == "SPHERE":
                radii.append(surf.Sphere().Radius())
            else:
                cyl = surf.Cylinder()
                radii.append(cyl.Radius())
                # Every cylinder on this object stands upright, so it prints cleanly.
                assert abs(cyl.Axis().Direction().Z()) == pytest.approx(1.0, abs=1e-9)
        assert any(abs(r - want_r) < GEOM_TOL for r in radii), f"{fid}: radii found {radii}"

    elif row["primitive"] == "plane-pair":
        planes = [(f.normalAt(), f.Center()) for f in faces_in(solid, region, "PLANE")]
        gaps = []
        for i, (n1, c1) in enumerate(planes):
            for n2, c2 in planes[i + 1 :]:
                if acute_angle(n1, n2) < 1e-6:
                    gaps.append(abs((c2 - c1).dot(n1)))
        assert any(abs(g - value) < GEOM_TOL for g in gaps), f"{fid}: no parallel faces {value} mm apart"

    else:  # plane-angle
        normals = [f.normalAt() for f in faces_in(solid, region, "PLANE")]
        angles = [acute_angle(a, b) for i, a in enumerate(normals) for b in normals[i + 1 :]]
        assert any(abs(a - value) < GEOM_TOL for a in angles), f"{fid}: no faces at {value} degrees"


# ---------------------------------------------------------------------------
# Printability (FR-8.5) and the STL itself
# ---------------------------------------------------------------------------


def test_stl_is_watertight(triangles):
    assert len(triangles) > 1000
    open_edges, flipped = edge_problems(triangles)
    assert open_edges == 0, f"{open_edges} open or over-shared edges"
    assert flipped == 0, f"{flipped} edges with inconsistent triangle direction"


def test_watertight_check_catches_a_hole(triangles):
    # Edge case for the checker itself: removing one triangle must open the mesh.
    open_edges, _ = edge_problems(triangles[:-1])
    assert open_edges >= 3


def test_no_unsupported_overhang(triangles):
    # A downward-facing surface steeper than 45 degrees from vertical needs support,
    # unless it is the underside lying on the bed.
    bad = []
    for tri in triangles:
        n = tri_normal(tri)
        if n is None or n[2] >= -math.cos(math.radians(45)) - 1e-6:
            continue
        if max(v[2] for v in tri) > 1e-3:
            bad.append(tri)
    assert not bad, f"{len(bad)} overhanging triangles, first {bad[0]}"


def test_minimum_wall():
    assert ro.RIB_T >= ro.MIN_WALL
    assert ro.STAIR_CHAMFER < ro.STAIR_UPPER_RISE


# ---------------------------------------------------------------------------
# FR-8.3 no symmetry
# ---------------------------------------------------------------------------


def test_shape_has_no_mirror_or_half_turn_symmetry(solid):
    ratios = symmetric_volume_ratios(solid)
    for name, ratio in ratios.items():
        assert ratio < 0.97, f"shape nearly matches its {name} copy ({ratio:.3f})"


def test_symmetry_check_catches_a_symmetric_shape():
    # Edge case for the checker itself: a plain block is symmetric every way.
    block = cq.Workplane("XY").box(40, 30, 20).val()
    assert all(r == pytest.approx(1.0, abs=1e-6) for r in symmetric_volume_ratios(block).values())


def test_feature_layout_has_no_symmetry(table):
    lo, hi = table["overall"]["min"], table["overall"]["max"]
    c = [(a + b) / 2 for a, b in zip(lo, hi)]
    # Each transform flips some axes about the centre: a mirror flips one, a half turn two.
    flips = {
        "mirror X": (0,),
        "mirror Y": (1,),
        "mirror Z": (2,),
        "half turn about X": (1, 2),
        "half turn about Y": (0, 2),
        "half turn about Z": (0, 1),
    }
    rows = table["features"]
    for name, axes in flips.items():
        matched = 0
        for row in rows:
            rmin, rmax = list(row["region"]["min"]), list(row["region"]["max"])
            for a in axes:
                rmin[a], rmax[a] = 2 * c[a] - rmax[a], 2 * c[a] - rmin[a]
            if any(
                other["kind"] == row["kind"]
                and all(abs(p - q) < 1.0 for p, q in zip(rmin + rmax, other["region"]["min"] + other["region"]["max"]))
                for other in rows
            ):
                matched += 1
        assert matched < len(rows) / 2, f"feature layout largely survives {name} ({matched}/{len(rows)})"
