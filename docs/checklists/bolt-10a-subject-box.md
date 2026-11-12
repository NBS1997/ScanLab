# On-Device Checklist — Bolt 10a, Subject Box and Coverage Dome

Build: ScanLab 0.1.x build 8, delivered through TestFlight (group "Owner").
Covers U09 part 1 (business rules SB-1 to SB-9, CD-1 to CD-5).
Tick each item on the phone. Anything that fails: note what you saw, and export the log
from Diagnostics if you can.

You need: a part on a table with some clear space round it (a kayak fitting is ideal),
and room to walk round it.

## Choosing the subject (SB-1 to SB-6)

1. [ ] New scan → Sweep. Once the camera runs, the banner says "Tap the part you want to
   scan." Finish is not available yet, and the bottom shows **Scan everything**.
2. [ ] Tap the part. Within about a second a **yellow box** appears round it, sitting on
   the table, and the banner asks "Is the yellow box round the part? …". **Smaller**,
   **Bigger** and **Scan this** appear.
3. [ ] The box fits the part: not much table inside it, no part sticking out. (It is
   lined up with the room, not the part, so a part at an angle gets a roomier box.)
4. [ ] **Bigger** and **Smaller** grow and shrink the box; its bottom stays on the
   table.
5. [ ] Tap the table beside the part: the banner says "That is the surface it sits on.
   Tap the part itself." Tap empty space far away or the sky: a "No depth there…" or
   "Could not find the part…" message. Nothing breaks; tap the part again to go on.
6. [ ] Tap a part with something else touching it (a cable, your hand): note whether
   the box takes in both.

## Scanning inside the box (SB-7, SB-8)

7. [ ] **Scan this**: the box turns **green**, the coverage ring appears at the bottom,
   and the depth-picture count starts rising.
8. [ ] Walk slowly right round the part at 20–50 cm, then from above. Patches on the ring
   turn green as you go; the white outline follows where you are.
9. [ ] The banner tells you where to go: "Go round to your left / right", "Raise the
   phone and look down on it", "Lower the phone…". Check left and right are the right
   way round.
10. [ ] When every patch is green, the phone buzzes once and the banner says "All round
    covered. Tap Finish when ready."
11. [ ] Finish. The model has **only the part**: no table, no background. The bottom
    resting on the table is open (that side cannot be seen).
12. [ ] Compare detail with a build 7 sweep of the same part: the boxed scan uses 3 mm
    cubes instead of 4 mm, so edges should be a little crisper.

## Scan everything (SB-1)

13. [ ] Start a new sweep and tap **Scan everything** straight away: no box, no ring,
    and it behaves as build 7 did.

## Diagnostics (SB-9)

14. [ ] Under `capture`: **Subject found** (size in mm, floor found, mask yes/no,
    readings, ms) or **Subject not found** (reason); **Fusion started** with voxel 3.0
    mm and subject box; **Coverage half way**; **Coverage complete**; **Coverage at
    finish**. Under `ui`: **Subject locked**, **Subject box resized**, or **Whole scene
    chosen**.

## Things to tell me

- How long a tap takes to show the box (the "ms" on **Subject found**), and whether
  "mask" says yes (Vision outlined the part) or no.
- Whether the box fits well, and which parts it struggles with.
- The "ms per picture" and "skipped" from **Fusion finished**: 3 mm cubes are more work.
