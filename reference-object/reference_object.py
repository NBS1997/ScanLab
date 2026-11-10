"""ScanLab reference object (Unit U03, ADR-010).

One parametric source for four outputs, written in one run:

    output/reference-object.stl    - to print (millimetres)
    output/reference-object.step   - to open in Autodesk Fusion
    output/feature-table.json      - the feature table the app bundles (U10/U11)
    output/measurement-sheet.md    - the caliper sheet the owner fills in

Run it with CadQuery 2 installed:

    python reference-object/reference_object.py

Coordinate frame (object coordinates, millimetres):
    X runs left to right along the long straight front edge.
    Y runs from the front edge (Y = 0) towards the back.
    Z runs up from the underside, which sits on the print bed (Z = 0).

Looking down on the object with the long straight edge nearest you, the tall tower is
at the back left, the stairs are at the front right, and the left side is a gentle
outward curve. Nothing about the layout repeats under a mirror or a half turn, so a
scan can be matched to it in only one orientation (FR-8.3).

Every number below is a design value. The printed part will differ slightly; the
owner's caliper value, not the design value, is the truth the app compares scans with.
"""

from __future__ import annotations

import inspect
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path

import cadquery as cq

HERE = Path(__file__).resolve().parent
OUTPUT_DIR = HERE / "output"

TABLE_VERSION = 1

# Printer build volume (FR-8.1): 340 x 320 x 340 mm.
PRINTER_VOLUME = (340.0, 320.0, 340.0)

# ---------------------------------------------------------------------------
# Base plate outline (plan view). The outline is deliberately lopsided:
#   - front edge: straight, along Y = 0, from X = 30 to X = 160
#   - right edge: straight, along X = 160
#   - back: a slanted edge at 10 degrees to the front edge, then a short straight
#     piece along Y = 105
#   - left: a large-radius outward curve (R 150)
#   - front-left corner: cut off at 30 degrees to the front edge
# ---------------------------------------------------------------------------
PLATE_THICKNESS = 8.0
PLATE_RIGHT_X = 160.0
PLATE_BACK_Y = 105.0

CORNER_CUT_ANGLE = 30.0  # degrees between the corner cut face and the front face
CORNER_CUT_FRONT_X = 30.0  # where the cut meets the front edge
ARC_CHORD_X = 8.0  # the curved left side starts and ends on this line

SLANT_ANGLE_TO_FRONT = 10.0  # degrees between the slanted back edge and the front edge
SLANT_LEFT_X = 60.0  # where the slanted back edge meets the short straight back piece

LEFT_ARC_RADIUS = 150.0

# The corner cut runs from the front edge up to the start of the left curve.
CORNER_CUT_LEFT_Y = (CORNER_CUT_FRONT_X - ARC_CHORD_X) * math.tan(math.radians(CORNER_CUT_ANGLE))

# The slanted back edge drops as it runs right, so it meets the right edge lower down.
SLANT_RIGHT_Y = PLATE_BACK_Y - (PLATE_RIGHT_X - SLANT_LEFT_X) * math.tan(math.radians(SLANT_ANGLE_TO_FRONT))

# The left curve is an arc of radius 150 through the two chord ends. Its "bulge" (how
# far the middle of the curve sits out from the straight line between its ends) follows
# from circle geometry: bulge = R - sqrt(R^2 - (chord / 2)^2).
ARC_CHORD = PLATE_BACK_Y - CORNER_CUT_LEFT_Y
ARC_BULGE = LEFT_ARC_RADIUS - math.sqrt(LEFT_ARC_RADIUS**2 - (ARC_CHORD / 2) ** 2)
ARC_MID = (ARC_CHORD_X - ARC_BULGE, (PLATE_BACK_Y + CORNER_CUT_LEFT_Y) / 2)

# ---------------------------------------------------------------------------
# Raised and cut features. All positions are plan-view (X, Y) on the plate.
# ---------------------------------------------------------------------------
TOP = PLATE_THICKNESS  # Z of the plate's top face

# Tall tower at the back left. One vertical edge is rounded (C1).
TOWER_X0, TOWER_Y0 = 12.0, 70.0
TOWER_W, TOWER_D, TOWER_H = 22.0, 26.0, 100.0  # width (X), depth (Y), height above plate
TOWER_FILLET = 1.5

# Two-step stairs at the front right. The upper step's front top edge is chamfered (A1).
STAIR_X0, STAIR_Y0, STAIR_D = 108.0, 8.0, 28.0
STAIR_LOWER_W, STAIR_LOWER_H = 20.0, 10.0  # lower tread: 10 mm above the plate
STAIR_UPPER_W, STAIR_UPPER_RISE = 24.0, 15.0  # upper tread: 15 mm above the lower one
STAIR_CHAMFER = 1.2  # 45 degree chamfer, 1.2 mm along each leg

# Ramp (wedge) at the front middle, rising to the right at 25 degrees.
RAMP_X0, RAMP_Y0 = 70.0, 8.0
RAMP_RUN, RAMP_W = 30.0, 15.0
RAMP_ANGLE = 25.0
RAMP_RISE = RAMP_RUN * math.tan(math.radians(RAMP_ANGLE))

# Low square pad, 1.5 mm proud of the plate.
PAD_X0, PAD_Y0, PAD_W, PAD_D, PAD_H = 64.0, 30.0, 20.0, 12.0, 1.5

# Thin upright rib near the right edge, 1.6 mm thick.
RIB_X0, RIB_Y0, RIB_T, RIB_L, RIB_H = 153.0, 45.0, 1.6, 30.0, 10.0

# Through slot, 6 mm wide.
SLOT_X0, SLOT_Y0, SLOT_W, SLOT_L = 70.0, 78.0, 6.0, 20.0

# Half-ball dome sitting on the plate (a sphere cut in half at the plate's top face).
DOME_CENTRE = (85.0, 60.0)
DOME_RADIUS = 15.0

# Through holes: (id, centre X, centre Y, diameter). Vertical, through the plate.
HOLES = [
    ("H1", 20.0, 60.0, 2.0),
    ("H2", 102.0, 40.0, 5.0),
    ("H3", 62.0, 20.0, 12.0),
    ("H4", 40.0, 38.0, 30.0),
]

# Round bosses: (id, centre X, centre Y, diameter, height above the plate).
BOSSES = [
    ("B1", 60.0, 62.0, 2.0, 4.0),
    ("B2", 95.0, 88.0, 8.0, 6.0),
    ("B3", 52.0, 85.0, 20.0, 12.0),
    ("B4", 126.0, 64.0, 40.0, 4.0),
]

# Minimum wall the slicer can print reliably (brief: walls >= 1.2 mm).
MIN_WALL = 1.2

# Regions in the feature table are grown by this much so that points sampled right on
# a face's edge still fall inside. They are then clipped to the overall box.
REGION_MARGIN = 0.25

# Size classes used by the accuracy report (FR-9.6). Upper bounds in millimetres.
SIZE_CLASSES = [("small", 5.0), ("medium", 30.0), ("large", math.inf)]


# ---------------------------------------------------------------------------
# Geometry
# ---------------------------------------------------------------------------


def _check_box(name: str, wp: cq.Workplane, expected_min, expected_max, tol: float = 1e-3) -> None:
    """Fail loudly if a part did not land where the parameters say it should."""
    bb = wp.val().BoundingBox()
    got_min = (bb.xmin, bb.ymin, bb.zmin)
    got_max = (bb.xmax, bb.ymax, bb.zmax)
    for got, want in zip(got_min + got_max, tuple(expected_min) + tuple(expected_max)):
        if abs(got - want) > tol:
            raise RuntimeError(f"{name}: bounding box {got_min}..{got_max}, expected {expected_min}..{expected_max}")


def _box(x0: float, y0: float, z0: float, w: float, d: float, h: float) -> cq.Workplane:
    """An axis-aligned block with its lowest corner at (x0, y0, z0)."""
    return cq.Workplane("XY").box(w, d, h, centered=False).translate((x0, y0, z0))


def _plate() -> cq.Workplane:
    """The base plate, traced anticlockwise from the right-hand end of the corner cut."""
    return (
        cq.Workplane("XY")
        .moveTo(CORNER_CUT_FRONT_X, 0.0)
        .lineTo(PLATE_RIGHT_X, 0.0)
        .lineTo(PLATE_RIGHT_X, SLANT_RIGHT_Y)
        .lineTo(SLANT_LEFT_X, PLATE_BACK_Y)
        .lineTo(ARC_CHORD_X, PLATE_BACK_Y)
        .threePointArc(ARC_MID, (ARC_CHORD_X, CORNER_CUT_LEFT_Y))
        .close()
        .extrude(PLATE_THICKNESS)
    )


def _tower() -> cq.Workplane:
    tower = _box(TOWER_X0, TOWER_Y0, TOP, TOWER_W, TOWER_D, TOWER_H)
    # Round only the front-right vertical edge: "|Z" keeps vertical edges, ">X" those at
    # the largest X, "<Y" those at the smallest Y. Exactly one edge satisfies all three.
    return tower.edges("|Z and >X and <Y").fillet(TOWER_FILLET)


def _stairs() -> cq.Workplane:
    lower = _box(STAIR_X0, STAIR_Y0, TOP, STAIR_LOWER_W, STAIR_D, STAIR_LOWER_H)
    upper = _box(
        STAIR_X0 + STAIR_LOWER_W, STAIR_Y0, TOP, STAIR_UPPER_W, STAIR_D, STAIR_LOWER_H + STAIR_UPPER_RISE
    )
    # Chamfer the upper step's front top edge: parallel to X, at the smallest Y, at the
    # largest Z. The chamfer faces up and forwards, so it prints without support.
    upper = upper.edges("|X and <Y and >Z").chamfer(STAIR_CHAMFER)
    return lower.union(upper)


def _ramp() -> cq.Workplane:
    """A wedge: a right-angled triangle in side view, swept 15 mm deep.

    The triangle is drawn on the XZ plane and extruded. Which way an XZ extrusion runs
    along Y is a CadQuery convention, so rather than rely on it the wedge is moved
    afterwards so that its front face sits exactly at RAMP_Y0.
    """
    wedge = (
        cq.Workplane("XZ")
        .polyline([(RAMP_X0, TOP), (RAMP_X0 + RAMP_RUN, TOP), (RAMP_X0 + RAMP_RUN, TOP + RAMP_RISE)])
        .close()
        .extrude(RAMP_W)
    )
    bb = wedge.val().BoundingBox()
    return wedge.translate((0.0, RAMP_Y0 - bb.ymin, 0.0))


def _dome() -> cq.Workplane:
    """Upper half of a ball, its flat face on the plate's top face."""
    cx, cy = DOME_CENTRE
    ball = cq.Workplane("XY").sphere(DOME_RADIUS).translate((cx, cy, TOP))
    keep_above_plate = _box(
        cx - DOME_RADIUS - 1, cy - DOME_RADIUS - 1, TOP, 2 * DOME_RADIUS + 2, 2 * DOME_RADIUS + 2, DOME_RADIUS + 1
    )
    return ball.intersect(keep_above_plate)


def build() -> cq.Solid:
    """Build the reference object as one valid solid."""
    plate = _plate()
    tower = _tower()
    stairs = _stairs()
    ramp = _ramp()
    dome = _dome()
    pad = _box(PAD_X0, PAD_Y0, TOP, PAD_W, PAD_D, PAD_H)
    rib = _box(RIB_X0, RIB_Y0, TOP, RIB_T, RIB_L, RIB_H)

    _check_box("tower", tower, (TOWER_X0, TOWER_Y0, TOP), (TOWER_X0 + TOWER_W, TOWER_Y0 + TOWER_D, TOP + TOWER_H))
    _check_box(
        "ramp",
        ramp,
        (RAMP_X0, RAMP_Y0, TOP),
        (RAMP_X0 + RAMP_RUN, RAMP_Y0 + RAMP_W, TOP + RAMP_RISE),
    )
    _check_box(
        "dome",
        dome,
        (DOME_CENTRE[0] - DOME_RADIUS, DOME_CENTRE[1] - DOME_RADIUS, TOP),
        (DOME_CENTRE[0] + DOME_RADIUS, DOME_CENTRE[1] + DOME_RADIUS, TOP + DOME_RADIUS),
    )

    body = plate.union(tower).union(stairs).union(ramp).union(dome).union(pad).union(rib)
    for _bid, x, y, dia, height in BOSSES:
        body = body.union(cq.Workplane("XY", origin=(x, y, TOP)).circle(dia / 2).extrude(height))

    # Cut the through holes and the slot. Cutters start 1 mm below the underside and end
    # 1 mm above the top so no paper-thin skin is left behind.
    for _hid, x, y, dia in HOLES:
        body = body.cut(cq.Workplane("XY", origin=(x, y, -1.0)).circle(dia / 2).extrude(PLATE_THICKNESS + 2))
    body = body.cut(_box(SLOT_X0, SLOT_Y0, -1.0, SLOT_W, SLOT_L, PLATE_THICKNESS + 2))

    solids = body.solids().vals()
    if len(solids) != 1:
        raise RuntimeError(f"expected one solid, got {len(solids)}; a feature is floating or overlapping wrongly")
    solid = solids[0]
    if not solid.isValid():
        raise RuntimeError("the solid is not valid; check feature overlaps")
    return solid


def overall_box(solid: cq.Solid) -> dict:
    bb = solid.BoundingBox()
    lo = [round(v, 3) for v in (bb.xmin, bb.ymin, bb.zmin)]
    hi = [round(v, 3) for v in (bb.xmax, bb.ymax, bb.zmax)]
    return {"min": lo, "max": hi, "size": [round(h - l, 3) for l, h in zip(lo, hi)]}


# ---------------------------------------------------------------------------
# Feature table
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class Feature:
    id: str
    kind: str  # length | step | hole | boss | angle | curve
    description: str
    design_value: float
    unit: str  # mm | deg
    size_mm: float  # characteristic size used for "three or more sizes" and size classes
    measure: str  # plain-English caliper instruction
    region_min: tuple
    region_max: tuple
    primitive: str  # plane-pair | cylinder | sphere | plane-angle


def _size_class(size_mm: float) -> str:
    for name, upper in SIZE_CLASSES:
        if size_mm <= upper:
            return name
    raise AssertionError("unreachable")


def features() -> list[Feature]:
    """Every measurable feature, with its design value and where it is on the object.

    Regions are axis-aligned boxes in object coordinates that enclose the surfaces (or,
    for very large faces such as the plate top, a nearby patch of them) that define the
    feature. Later Units fit the primitive to the scan points inside each region.
    """
    f: list[Feature] = []
    T = TOP

    # -- Lengths: distance between two parallel faces ------------------------------
    f.append(
        Feature(
            "L1",
            "length",
            "Thickness of the thin upright rib near the right edge",
            RIB_T,
            "mm",
            RIB_T,
            "Close the outside jaws gently on the thin rib near the right-hand edge, across its thickness (left to right).",
            (RIB_X0, RIB_Y0, T),
            (RIB_X0 + RIB_T, RIB_Y0 + RIB_L, T + RIB_H),
            "plane-pair",
        )
    )
    f.append(
        Feature(
            "L2",
            "length",
            "Width of the through slot behind the dome",
            SLOT_W,
            "mm",
            SLOT_W,
            "Put the small inside jaws into the long narrow slot and open them across its width (left to right).",
            (SLOT_X0, SLOT_Y0, 0.0),
            (SLOT_X0 + SLOT_W, SLOT_Y0 + SLOT_L, PLATE_THICKNESS),
            "plane-pair",
        )
    )
    f.append(
        Feature(
            "L3",
            "length",
            "Width of the tall tower, left face to right face",
            TOWER_W,
            "mm",
            TOWER_W,
            "Close the outside jaws on the tall tower from left to right, about halfway up, away from the rounded corner.",
            (TOWER_X0, TOWER_Y0, T),
            (TOWER_X0 + TOWER_W, TOWER_Y0 + TOWER_D, T + TOWER_H),
            "plane-pair",
        )
    )
    f.append(
        Feature(
            "L4",
            "length",
            "Depth of the tall tower, front face to back face",
            TOWER_D,
            "mm",
            TOWER_D,
            "Close the outside jaws on the tall tower from front to back, about halfway up.",
            (TOWER_X0, TOWER_Y0, T),
            (TOWER_X0 + TOWER_W, TOWER_Y0 + TOWER_D, T + TOWER_H),
            "plane-pair",
        )
    )
    f.append(
        Feature(
            "L5",
            "length",
            "Front-to-back depth of the plate at the left, front edge to the short straight back edge",
            PLATE_BACK_Y,
            "mm",
            PLATE_BACK_Y,
            "Close the outside jaws on the plate edges from front to back, between the large hole and the curved left "
            "side, where the back edge is straight and parallel to the front edge (about 4 cm in from the corner cut).",
            (CORNER_CUT_FRONT_X, 0.0, 0.0),
            (SLANT_LEFT_X, PLATE_BACK_Y, PLATE_THICKNESS),
            "plane-pair",
        )
    )
    f.append(
        Feature(
            "L6",
            "length",
            "Overall height, underside to the top of the tall tower",
            PLATE_THICKNESS + TOWER_H,
            "mm",
            PLATE_THICKNESS + TOWER_H,
            "Close the outside jaws from the underside of the plate to the top of the tall tower, reaching in from "
            "the curved left side.",
            (TOWER_X0, TOWER_Y0, 0.0),
            (TOWER_X0 + TOWER_W, TOWER_Y0 + TOWER_D, T + TOWER_H),
            "plane-pair",
        )
    )

    # -- Steps: height between two parallel horizontal faces ------------------------
    f.append(
        Feature(
            "S1",
            "step",
            "Height of the low square pad above the plate",
            PAD_H,
            "mm",
            PAD_H,
            "Stand the end of the calipers on the low square pad and slide the depth rod down until it touches the "
            "plate beside the pad.",
            (PAD_X0 - 2, PAD_Y0 - 2, T),
            (PAD_X0 + PAD_W + 2, PAD_Y0 + PAD_D + 2, T + PAD_H),
            "plane-pair",
        )
    )
    f.append(
        Feature(
            "S2",
            "step",
            "Plate thickness, underside to plate top",
            PLATE_THICKNESS,
            "mm",
            PLATE_THICKNESS,
            "Close the outside jaws on the plate at the front edge, underside to top, clear of the ramp and stairs.",
            (40.0, 0.0, 0.0),
            (65.0, 6.0, PLATE_THICKNESS),
            "plane-pair",
        )
    )
    f.append(
        Feature(
            "S3",
            "step",
            "Height of the lower stair tread above the plate",
            STAIR_LOWER_H,
            "mm",
            STAIR_LOWER_H,
            "Stand the end of the calipers on the lower stair tread and slide the depth rod down to the plate on "
            "its left.",
            (105.0, STAIR_Y0 - 4, T),
            (STAIR_X0 + STAIR_LOWER_W, STAIR_Y0 + STAIR_D + 4, T + STAIR_LOWER_H),
            "plane-pair",
        )
    )
    f.append(
        Feature(
            "S4",
            "step",
            "Rise from the lower stair tread to the upper stair tread",
            STAIR_UPPER_RISE,
            "mm",
            STAIR_UPPER_RISE,
            "Stand the end of the calipers on the upper stair tread and slide the depth rod down to the lower tread.",
            (STAIR_X0, STAIR_Y0, T + STAIR_LOWER_H),
            (STAIR_X0 + STAIR_LOWER_W + STAIR_UPPER_W, STAIR_Y0 + STAIR_D, T + STAIR_LOWER_H + STAIR_UPPER_RISE),
            "plane-pair",
        )
    )
    f.append(
        Feature(
            "S5",
            "step",
            "Height of the tall tower above the plate",
            TOWER_H,
            "mm",
            TOWER_H,
            "Hard to reach directly: measure L6 (overall height) and S2 (plate thickness) and write L6 minus S2 here. "
            "If your depth rod is long enough, you can instead stand the calipers on the tower top and drop the rod "
            "to the plate.",
            (TOWER_X0 - 4, TOWER_Y0 - 4, T),
            (TOWER_X0 + TOWER_W + 4, TOWER_Y0 + TOWER_D + 4, T + TOWER_H),
            "plane-pair",
        )
    )

    # -- Holes: vertical, through the plate ------------------------------------------
    for hid, x, y, dia in HOLES:
        hint = (
            " The jaw tips may be too thick for a hole this small; if so, find the largest drill bit that slides "
            "in and measure the drill bit instead."
            if dia <= 2.0
            else ""
        )
        f.append(
            Feature(
                hid,
                "hole",
                f"Diameter of the {dia:g} mm round through hole",
                dia,
                "mm",
                dia,
                "Put the small inside jaws into the round hole and open them until they touch both sides; rock them "
                "slightly and keep the largest reading." + hint,
                (x - dia / 2, y - dia / 2, 0.0),
                (x + dia / 2, y + dia / 2, PLATE_THICKNESS),
                "cylinder",
            )
        )

    # -- Bosses: vertical round posts on the plate ---------------------------------------
    for bid, x, y, dia, height in BOSSES:
        f.append(
            Feature(
                bid,
                "boss",
                f"Diameter of the {dia:g} mm round post ({height:g} mm tall)",
                dia,
                "mm",
                dia,
                "Close the outside jaws across the round post, near its top, and keep the smallest steady reading.",
                (x - dia / 2, y - dia / 2, T),
                (x + dia / 2, y + dia / 2, T + height),
                "cylinder",
            )
        )

    # -- Angles: the acute angle between two flat faces ------------------------------------
    protractor_note = " If your protractor reads more than 90 degrees, write 180 minus the reading."
    upper_top = T + STAIR_LOWER_H + STAIR_UPPER_RISE
    f.append(
        Feature(
            "A1",
            "angle",
            "Small chamfer on the front top edge of the upper stair, against the stair top",
            45.0,
            "deg",
            round(STAIR_CHAMFER * math.sqrt(2), 3),
            "Too small for a protractor. With the depth rod, measure how far the chamfer runs down the front face "
            "(design 1.2 mm), and with the jaws how far it runs back across the top (design 1.2 mm). Angle = "
            "arctan(down / back). Leave blank if you cannot measure it.",
            (STAIR_X0 + STAIR_LOWER_W, STAIR_Y0, upper_top - 2 * STAIR_CHAMFER),
            (STAIR_X0 + STAIR_LOWER_W + STAIR_UPPER_W, STAIR_Y0 + 3 * STAIR_CHAMFER, upper_top),
            "plane-angle",
        )
    )
    f.append(
        Feature(
            "A2",
            "angle",
            "Corner cut at the front left, against the front face",
            CORNER_CUT_ANGLE,
            "deg",
            round(math.hypot(CORNER_CUT_FRONT_X - ARC_CHORD_X, CORNER_CUT_LEFT_Y), 3),
            "Hold a protractor against the long straight front face with its arm along the cut-off front-left "
            "corner." + protractor_note,
            (ARC_CHORD_X, 0.0, 0.0),
            (CORNER_CUT_FRONT_X + 10, CORNER_CUT_LEFT_Y, PLATE_THICKNESS),
            "plane-angle",
        )
    )
    f.append(
        Feature(
            "A3",
            "angle",
            "Sloping top of the ramp, against the plate top",
            RAMP_ANGLE,
            "deg",
            round(RAMP_RUN / math.cos(math.radians(RAMP_ANGLE)), 3),
            "Stand a protractor on the plate beside the ramp with its arm along the slope. No protractor? Measure the "
            "ramp's tall end with the depth rod (design 13.99 mm) and its length along the plate with the jaws "
            "(design 30 mm); angle = arctan(height / length).",
            (68.5, RAMP_Y0 - 5, T),
            (RAMP_X0 + RAMP_RUN, RAMP_Y0 + RAMP_W, T + RAMP_RISE),
            "plane-angle",
        )
    )
    slant_y_at_130 = SLANT_RIGHT_Y + (PLATE_RIGHT_X - 130.0) * math.tan(math.radians(SLANT_ANGLE_TO_FRONT))
    f.append(
        Feature(
            "A4",
            "angle",
            "Long slanted back edge, against the right-hand face at the back right corner",
            90.0 - SLANT_ANGLE_TO_FRONT,
            "deg",
            round((PLATE_RIGHT_X - SLANT_LEFT_X) / math.cos(math.radians(SLANT_ANGLE_TO_FRONT)), 3),
            "Hold a protractor at the back right corner, one arm along the right-hand face and the other along the "
            "long slanted back face." + protractor_note,
            (130.0, 72.0, 0.0),
            (PLATE_RIGHT_X, slant_y_at_130, PLATE_THICKNESS),
            "plane-angle",
        )
    )

    # -- Curves: radius of a curved surface ---------------------------------------------
    f.append(
        Feature(
            "C1",
            "curve",
            "Radius of the rounded front-right vertical edge of the tall tower",
            TOWER_FILLET,
            "mm",
            TOWER_FILLET,
            "Calipers cannot measure this directly. Use a radius gauge if you have one; otherwise leave blank.",
            (TOWER_X0 + TOWER_W - TOWER_FILLET, TOWER_Y0, T),
            (TOWER_X0 + TOWER_W, TOWER_Y0 + TOWER_FILLET, T + TOWER_H),
            "cylinder",
        )
    )
    f.append(
        Feature(
            "C2",
            "curve",
            "Radius of the half-ball dome",
            DOME_RADIUS,
            "mm",
            DOME_RADIUS,
            "Stand the end of the calipers on the top of the dome and slide the depth rod down to the plate; for a "
            "half ball the height equals the radius. (Check: the dome's width across its base should be twice this.)",
            (DOME_CENTRE[0] - DOME_RADIUS, DOME_CENTRE[1] - DOME_RADIUS, T),
            (DOME_CENTRE[0] + DOME_RADIUS, DOME_CENTRE[1] + DOME_RADIUS, T + DOME_RADIUS),
            "sphere",
        )
    )
    f.append(
        Feature(
            "C3",
            "curve",
            "Radius of the gently curved left side",
            LEFT_ARC_RADIUS,
            "mm",
            LEFT_ARC_RADIUS,
            f"Lay a steel rule on edge against the two ends of the curved left side (design gap {ARC_CHORD:.2f} mm "
            f"between the ends). With the depth rod, measure the gap between the rule and the middle of the curve "
            f"(design {ARC_BULGE:.2f} mm). Radius = (ends gap x ends gap) / (8 x middle gap) + middle gap / 2.",
            (ARC_MID[0], CORNER_CUT_LEFT_Y, 0.0),
            (ARC_CHORD_X, PLATE_BACK_Y, PLATE_THICKNESS),
            "cylinder",
        )
    )
    return f


def _grow_and_clip(lo, hi, overall: dict):
    omin, omax = overall["min"], overall["max"]
    glo = [round(max(v - REGION_MARGIN, omin[i]), 3) for i, v in enumerate(lo)]
    ghi = [round(min(v + REGION_MARGIN, omax[i]), 3) for i, v in enumerate(hi)]
    return glo, ghi


def feature_table(solid: cq.Solid) -> dict:
    overall = overall_box(solid)
    rows = []
    for feat in features():
        lo, hi = _grow_and_clip(feat.region_min, feat.region_max, overall)
        rows.append(
            {
                "id": feat.id,
                "kind": feat.kind,
                "description": feat.description,
                "designValue": round(feat.design_value, 3),
                "unit": feat.unit,
                "sizeMm": round(feat.size_mm, 3),
                "sizeClass": _size_class(feat.size_mm),
                "measure": feat.measure,
                "region": {"min": lo, "max": hi},
                "primitive": feat.primitive,
            }
        )
    return {
        "version": TABLE_VERSION,
        "units": {"length": "mm", "angle": "deg"},
        "coordinateFrame": (
            "Object coordinates in millimetres. X along the long straight front edge (left to right), Y from the "
            "front edge towards the back, Z up from the underside (the print-bed face, Z = 0)."
        ),
        "angleConvention": "Angles are the acute angle (0 to 90 degrees) between the planes of the two named faces.",
        "sizeClasses": {name: (None if math.isinf(upper) else upper) for name, upper in SIZE_CLASSES},
        "overall": overall,
        "volumeMm3": round(solid.Volume(), 1),
        "features": rows,
    }


# ---------------------------------------------------------------------------
# Measurement sheet
# ---------------------------------------------------------------------------

KIND_HEADINGS = [
    ("length", "Lengths between faces"),
    ("step", "Steps and heights"),
    ("hole", "Holes"),
    ("boss", "Round posts (bosses)"),
    ("angle", "Angles between faces"),
    ("curve", "Curved surfaces"),
]


def _fmt(value: float, unit: str) -> str:
    text = f"{value:.2f}".rstrip("0").rstrip(".")
    return f"{text} mm" if unit == "mm" else f"{text} degrees"


def measurement_sheet(table: dict) -> str:
    size = table["overall"]["size"]
    lines = [
        "# ScanLab reference object - measurement sheet",
        "",
        f"Table version {table['version']}. Overall design size {size[0]:g} x {size[1]:g} x {size[2]:g} mm "
        "(left to right x front to back x height).",
        "",
        "## Why you are measuring",
        "",
        "Every printer makes parts a little different from the design: plastic shrinks as it cools, holes come out",
        "small and posts come out large. The app compares each scan with **your caliper value**, not the design",
        "value. The caliper value is the truth; the design value is only there so you can spot a slip of the pen.",
        "If a reading is more than about 0.5 mm away from the design value, measure it again.",
        "",
        "## Before you measure",
        "",
        "- Let the print cool for at least an hour after it comes off the bed.",
        "- Zero the calipers with the jaws closed. Measure each feature three times and write down the average.",
        "- Hold the object the same way as this sheet: the **long straight edge towards you**, the **tall tower at",
        "  the back left**, the **stairs at the front right**, and the **curved side on your left**.",
        "- Leave a box blank rather than guess. A blank feature is simply left out of the accuracy report.",
        "",
        "## Print guidance",
        "",
        "- **Filament:** matt, light-coloured (white or light grey matt PLA is ideal). Shiny or dark plastic",
        "  confuses the depth sensor.",
        "- **Orientation:** flat on the bed, underside down, exactly as the STL is laid out. No supports are",
        "  needed: nothing overhangs more than 45 degrees.",
        "- **Settings:** 0.2 mm layers, 3 walls, 15-20% infill (gyroid or grid), no brim needed. Turn off any",
        "  slicer setting that compensates holes or shrinks the first layer, so the print matches the design as",
        "  closely as it naturally does.",
        "- Do not sand or paint it; measure and scan it as printed.",
        "",
        "## Features",
        "",
    ]
    by_kind: dict[str, list] = {}
    for row in table["features"]:
        by_kind.setdefault(row["kind"], []).append(row)
    for kind, heading in KIND_HEADINGS:
        lines += [f"### {heading}", "", "| ID | What to measure | Design value | Your caliper value |", "|---|---|---|---|"]
        for row in by_kind.get(kind, []):
            what = f"**{row['description']}.** {row['measure']}"
            lines.append(f"| {row['id']} | {what} | {_fmt(row['designValue'], row['unit'])} | |")
        lines.append("")
    lines += [
        "## Done?",
        "",
        "Enter your caliper values in the app (Reference object screen) once that screen exists. Keep this sheet:",
        "if you ever reprint the object, measure the new print and enter its values again.",
        "",
    ]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------


def _export_stl(solid: cq.Solid, path: Path) -> None:
    # 0.01 mm absolute chord tolerance keeps even the 2 mm hole round; binary STL keeps
    # the file small. Older CadQuery versions do not have the "relative" argument.
    kwargs = {"tolerance": 0.01, "angularTolerance": 0.1, "ascii": False}
    if "relative" in inspect.signature(solid.exportStl).parameters:
        kwargs["relative"] = False
    solid.exportStl(str(path), **kwargs)


def generate(output_dir: Path = OUTPUT_DIR) -> dict:
    output_dir.mkdir(parents=True, exist_ok=True)
    solid = build()

    size = overall_box(solid)["size"]
    if any(s > limit for s, limit in zip(size, PRINTER_VOLUME)):
        raise RuntimeError(f"object {size} does not fit the printer volume {PRINTER_VOLUME}")
    if RIB_T < MIN_WALL:
        raise RuntimeError(f"rib thickness {RIB_T} mm is below the {MIN_WALL} mm minimum wall")

    table = feature_table(solid)
    _export_stl(solid, output_dir / "reference-object.stl")
    cq.exporters.export(solid, str(output_dir / "reference-object.step"), exportType="STEP")
    (output_dir / "feature-table.json").write_text(
        json.dumps(table, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n"
    )
    (output_dir / "measurement-sheet.md").write_text(measurement_sheet(table), encoding="utf-8", newline="\n")
    return table


def main() -> int:
    try:
        table = generate()
    except Exception as exc:  # report and fail the run; never write half the outputs silently
        print(f"reference object generation failed: {exc}", file=sys.stderr)
        raise
    o = table["overall"]["size"]
    print(f"Wrote {len(table['features'])} features; overall {o[0]} x {o[1]} x {o[2]} mm -> {OUTPUT_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
