# On-Device Checklist — Bolt 8, Accuracy Stage 1

Build: ScanLab 0.1.x, delivered through TestFlight (group "Owner").
Covers stories US-12 (entering caliper values, FR-8.6) and US-13 stage 1 (FR-9.1–9.4,
FR-9.6 by size class) and accessibility checks A1, A3, A4, A6, A10, A12. Tick each item
on the phone. Anything that fails: note what you saw, and export the log from
Diagnostics if you can.

The build already proved the sums: synthetic scans with a known error are reported
right to within 0.05 mm (FR-9.9). This list checks the screens and gives the **first
real accuracy figures**. Items 12–22 need a sweep or photo scan of the printed
reference object, so do them after Bolts 6 and 7 have merged too.

You need: the printed reference object, your filled-in measurement sheet
(`reference-object/output/measurement-sheet.md`), and the calipers.

## Caliper values (US-12, FR-8.6)

1. [ ] Add the sample to the library (Diagnostics › Add sample to library) and open it.
   Tap **•••**: there is **Mark as reference object**. Tap it. The details now say
   **Reference object: Yes** and **Check accuracy** is available.
2. [ ] Tap **Check accuracy**. The Accuracy screen opens and runs at once (step names and
   a percentage). Under **Your measurements** it says "No caliper values yet…". Tap
   **Reference object…**.
3. [ ] The sheet lists the features in the measurement sheet's groups (Lengths, Steps,
   Holes, Round posts, Angles, Curved surfaces), each with ID, description, "Design …"
   and an empty box with "mm" (or "°" for angles). "How to measure" opens the
   instruction. "Entered 0 of 26".
4. [ ] Validation: in H3 (design 12 mm) type `0` → red "Must be more than zero."; `1205`
   → red "Must be 500 mm or less."; `120.5` → red "Too far from the design value…";
   `abc` → red "Type a number…". **Save** is greyed out while any box is red.
5. [ ] In H3 type `12.8` → orange "More than 0.5 mm from the design value (12 mm).
   Measure again." Save is available. Type `12,05` (comma): accepted with no message.
6. [ ] In A2 (design 30°) type `95` → red "Must be 90° or less…"; then `29.5` → no
   message.
7. [ ] Enter **all your real caliper values** from the measurement sheet; leave blank
   any you did not measure. Tap **Save**. The sheet closes and Accuracy shows
   "Caliper values: N entered".
8. [ ] **Force-quit** ScanLab, reopen, open the scan › Check accuracy › Reference object…:
   every value is still there, exactly as typed (trailing zeros dropped). Change one,
   Save, reopen the sheet: the change is kept.

## Wrong objects are refused (FR-9.4)

9. [ ] Back on the sample's Accuracy screen (the check from item 2 has finished): it
   shows **Match unreliable · … mm** with a red cross, the sentence "Unreliable: this
   scan does not look like the reference object, so no accuracy figures are shown.",
   and a reason such as "Only 12% of the reference object's surface was found…".
   There is **no** "Surface error by size" table.
10. [ ] Go back: Scan detail shows a **grey seal with a cross** and "Accuracy report:
    unreliable". Go back to Scans: the sample's row has the same grey crossed seal, **not**
    a green tick; with VoiceOver it reads "Accuracy report: unreliable". Open it again › Check accuracy: the saved report
    appears immediately (no re-run).
11. [ ] Scan detail › **•••** › **Unmark as reference object**: Check accuracy is greyed
    out again, with "Check accuracy: mark this scan as the reference object first…"
    under the details.

## The printed reference object (US-13; after Bolts 6 and 7)

12. [ ] Put the printed object on a plain table, long straight edge towards you. Make a
    **sweep** scan of it (top and all sides). Open the scan › **•••** › **Mark as
    reference object** › **Check accuracy**.
13. [ ] A report appears without picking any points. Note the time it took (from tapping
    Check accuracy to the report): ______ s. It should be under about 15 s.
14. [ ] The **Match** line comes first: record it: Match ______ · ______ mm; Reference
    surface found ______ %; Scan close to the shape ______ %.
15. [ ] The verdict starts "The measured surface is within ±… mm of the true shape for 95%
    of the points counted" and ends "These are surface distances, not feature sizes."
    If any of the scan was left out it says "…% of the scan was more than 5 mm from the
    reference shape and is not counted."; if part of the object was missed it says "…% of
    the reference had no scan within 3 mm." Record it:
    ________________________________________________.
16. [ ] **Surface error by size** shows Measured surface (not "Whole surface"), Small (up to 5 mm), Medium
    (5–30 mm), Large (over 30 mm) and possibly Rest of the surface. Record each:

    | Row | Mean | RMS | 95% | Points |
    |---|---|---|---|---|
    | Measured surface | | | | |
    | Small | | | | |
    | Medium | | | | |
    | Large | | | | |
    | Rest of the surface | | | | |

16a. [ ] Below the table, **What was counted** shows Points counted, Points left out (a
    count and a percentage) and Reference with no scan nearby (a percentage). The
    sentences under them match the verdict's wording exactly. Record: counted ______,
    left out ______ (____ %), no scan nearby ____ %.
16b. [ ] If more than 10% was left out, the verdict is **not** rated good: the reason
    "…% of the scan was left out of the figures, more than the 10% allowed for a good
    rating…" appears under the verdict. (Left out ____ %; rating shown ______.)
16c. [ ] Go back to Scan detail and Scans: the seal matches the rating. **Good**: green
    seal with a tick, "Accuracy report: good". **Limited**: orange warning triangle,
    "Accuracy report: limited". **Unreliable**: grey seal with a cross (item 10). A scan
    checked before this build shows a plain grey seal, "Has an accuracy report", and its
    Accuracy screen says the points left out are unknown until Check again.

17. [ ] Tap **Check again**: the same figures come back (the check is repeatable). Tap
    Check again and then **Cancel** straight away: "Check cancelled" is not shown
    because the earlier report comes back; the figures are unchanged.
18. [ ] Make a **photo** scan of the printed object and repeat items 12–16c for it:

    | Row | Mean | RMS | 95% | Points |
    |---|---|---|---|---|
    | Match (line) | | | | |
    | Measured surface | | | | |
    | Small | | | | |
    | Medium | | | | |
    | Large | | | | |
    | Left out / no scan nearby (%) | | | | |

19. [ ] Scan **another object** (a mug, a box, anything) by either method, mark it as the
    reference object and check it: the report is **unreliable** with a reason and no
    figures.
20. [ ] If a report on the printed object came out unreliable or with a match worse than
    2 mm, note which reason was given: ________________ (this tunes the provisional
    thresholds of ADR-009).

## Accessibility and orientation

21. [ ] Turn the phone sideways on Accuracy and on the Reference object sheet: nothing is
    cut off. Set the largest text size: the size table and the caliper rows still read
    properly. Set it back.
22. [ ] With VoiceOver on: the match line and verdict are read; each size row is read as
    one item, e.g. "Small (up to 5 mm), mean plus 0.20 millimetres, RMS 0.25
    millimetres, 95 percent within 0.48 millimetres, 1,204 points". A caliper box reads
    "H3 caliper value in millimetres". Red and orange messages are read as text.
    "Check again", "Cancel", "Reference object…", "Mark as reference object" have
    sensible labels; a greyed-out Check accuracy reads its reason.

## Diagnostics log

23. [ ] Diagnostics › Activity has: **Reference object loaded** (faces, features: 26,
    ms); **Accuracy shown**; **Accuracy check started**; **Accuracy check finished**
    with quality, verdict, rmsMm, coverage, inliers, starts: 36, points, background,
    calipers, measured, excluded, excludedShare, uncovered, p95Mm per size class and ms
    per step; **Accuracy report saved** with verdict good, limited or unreliable;
    **Reference object sheet shown**; **Caliper values saved** (entered, warnings);
    **Reference mark changed**; and **Accuracy check cancelled** from item 17. No errors.

## Result

- [ ] All passed — approve Bolt 8 (items 12–20 are done once Bolts 6 and 7 are merged;
  the recorded figures are the first real accuracy findings).
- [ ] Something failed — describe it (and attach the exported log if possible).
