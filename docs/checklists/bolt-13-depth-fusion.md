# On-Device Checklist — Bolt 13, Depth Fusion

Build: ScanLab 0.1.x build 7, delivered through TestFlight (group "Owner").
Covers U14 (business rules DF-1 to DF-10) and US-06 (sweep capture, improved).
Tick each item on the phone. Anything that fails: note what you saw, and export the log
from Diagnostics if you can.

You need: the subject you swept in build 6 (so you can compare), the printed reference
object if you have it, and a kayak fitting or another part with edges and holes.

**How to sweep for fusion.** Hold the phone 20–50 cm from the subject (readings beyond
1 m are ignored). Move slowly and go right round it, including from above. Fusion
averages many views, so passing over the same area two or three times makes it
sharper, not worse.

## Scans survive the update

1. [ ] Install over build 6 without deleting the app. Every earlier scan is still listed
   and opens.

## Sweeping (DF-1, DF-5, DF-9)

2. [ ] Start a sweep. Once the wireframe appears, the line under the timer reads
   "… areas · … faces · N depth pictures", and N keeps rising while you move.
3. [ ] The camera picture and wireframe stay as smooth as in build 6 (fusion runs in the
   background and must not make the camera stutter).
4. [ ] Cover the camera or shake the phone until a tracking prompt appears: N stops
   rising while tracking is limited, and starts again once it recovers.

## The saved model (DF-3, DF-4, DF-7, DF-8)

5. [ ] Finish. Saving takes no more than about 10 seconds for a part-sized sweep (note
   the time if it is longer).
6. [ ] The model in Scan detail is visibly more detailed than the build 6 sweep of the
   same subject: edges, holes and steps show; flat faces are flat, not lumpy.
7. [ ] The model is upright and the right size (check one dimension with the measure
   tool you trust, or in Fusion).
8. [ ] Areas you only glimpsed once are left open (holes) rather than filled with
   guesses. Loose specks floating in the air are rare.
9. [ ] Export STL at the standard detail and open it in Fusion. Note the face count and
   whether Fusion handles it comfortably; try a lower detail if not.
10. [ ] If you have the reference object: run an accuracy report on a fused sweep of it,
    and note the 95% figure and the "left out" share. Compare with a build 6 sweep if
    you made one.

## Diagnostics (DF-10)

11. [ ] Diagnostics shows, for the sweep, under `capture`: **Fusion started** (voxel 4.0
    mm, band 16.0 mm, range 0.10–1.00 m), **Fusion finished** (pictures, skipped, ms
    per picture, extract s, pieces dropped, faces) and **Sweep model chosen** with
    source **depth fusion**. Note the "ms per picture" and "extract s" values: they say
    whether fusion needs to be faster.

## Long sweeps (DF-6)

12. [ ] Optional: sweep a whole room slowly for a couple of minutes. If memory fills, the
    prompt "Detail memory full. Finish now, or start again closer to the subject."
    appears, the log shows **Fusion memory full**, and Finish still saves a model.

## Things to tell me

- Which subjects came out well and which did not (dark, shiny or thin parts are the
  hardest for LiDAR).
- The "ms per picture", "skipped" and "extract s" values from item 11.
- Whether the detail is now limited by the sensor (fuzzy but solid) or by the method
  (blocky, stepped or with seams).
