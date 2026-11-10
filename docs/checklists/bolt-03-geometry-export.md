# On-Device Checklist — Bolt 3, Geometry and Export

Build: ScanLab with Bolt 3 (`geometry-export`), delivered through TestFlight.
Covers story US-11 (export path, using the built-in sample model) and accessibility
checks for the new Export screen. Tick each item. Anything that fails: note what you
saw, and export the log from Diagnostics if you can.

The sample model is a **stepped block with a round boss, 60 × 40 × 20 mm** overall
(base 60 × 40 × 10 mm, a step 20 mm long rising to 15 mm, a boss 16 mm across rising to
20 mm). Full has 19,840 faces.

## Open the Export screen

1. [ ] Open ScanLab, tap **Diagnostics**. A **Sample model** section shows
   "A built-in 60.0 × 40.0 × 20.0 mm stepped block…" and **Export sample model…**.
2. [ ] Tap **Export sample model…**. The **Export** sheet opens. Under **Model**: Name
   "Sample stepped block", Size **60.0 × 40.0 × 20.0 mm**, Faces **19,840 faces**.
3. [ ] Under **Detail level**, within a few seconds each level shows a face count:
   - [ ] **Full**: 19,840 faces.
   - [ ] **Fusion-friendly**: 10,000 faces or fewer (record: ______).
   - [ ] **Light**: 5,000 faces or fewer (record: ______).
4. [ ] Fusion-friendly is selected and **STL** is selected under File type.

## Export each level and type to iCloud Drive (FR-7.1, FR-7.3, FR-7.4)

Make a folder **iCloud Drive › ScanLab exports** the first time.

5. [ ] Tap **Choose where to save…**. The phone's file chooser opens on every export.
   Pick the folder and tap **Save** (the button may read **Move** or **Export**). The
   Export sheet shows "Saved Sample stepped block (Fusion-friendly).stl."
6. [ ] Repeat for the other five combinations: Full STL, Light STL, Full OBJ,
   Fusion-friendly OBJ, Light OBJ. Six files in total, each named
   "Sample stepped block (<level>).<stl|obj>".
7. [ ] Start one export and tap **Cancel** in the chooser. You return to the Export
   sheet with no error.
8. [ ] On the Windows PC, all six files appear in iCloud Drive › ScanLab exports.

## Fusion (FR-7.2, FR-7.3, PC2)

9. [ ] In Fusion: **Insert › Insert Mesh**, choose the Fusion-friendly STL, units
   **Millimetre**. It inserts without a warning about size.
10. [ ] Select the mesh body; the face count in the browser or Properties is 10,000 or
    fewer.
11. [ ] **Mesh › Modify › Convert Mesh** (Prismatic or Faceted, Parametric). It becomes
    a solid body.
12. [ ] Measure the solid's overall size (Inspect › Measure, or the bounding box):
    60.00 × 40.00 × 20.00 mm, each within **0.06 / 0.04 / 0.02 mm** (0.1%). Record:
    ______ × ______ × ______ mm.
13. [ ] Insert the Fusion-friendly OBJ the same way: the same size within 0.1%.

## Blender and a slicer (FR-7.1)

14. [ ] In Blender (File › Import › STL and OBJ), each file loads. With scene units in
    millimetres, the Dimensions panel shows 60 × 40 × 20 (Blender may show 0.06 m etc. if
    the scene is in metres with scale 0.001; either way, the same as Fusion).
15. [ ] In a slicer (for example Bambu Studio, PrusaSlicer or Cura), the Full STL and Full
    OBJ load at 60 × 40 × 20 mm without the slicer offering to rescale.

## Aeroplane mode (US-11)

16. [ ] Turn on aeroplane mode. Export Light STL and in the chooser pick **On My
    iPhone** (any folder). It saves. Turn aeroplane mode off.

## Diagnostics log entries (project rule)

17. [ ] Close the Export sheet, pull down on Diagnostics to refresh. Under **Activity**
    (category `export`) you see, for each export:
    - [ ] **Export opened** (model name).
    - [ ] **Export levels ready** with `faces`, `full`, `fusionFriendly`, `light` counts
      and `ms`.
    - [ ] **Export file written** with detail, format, faces, bytes and ms. For STL,
      bytes = 84 + 50 × faces (for example 10,000 faces → 500,084 bytes).
    - [ ] **Export saved** with the file and folder names, or **Export cancelled**.
18. [ ] No **Export file failed**, **Simplification failed** or
    **Temporary export file not removed** entries appear (unless item 19 produced them).

## Storage full (NFR-9) — only if convenient

19. [ ] *(Optional.)* With the phone nearly full, an export shows in red on the Export
    sheet: "There is not enough free space to write the file, so nothing was saved. Free
    up some space, then try again." An **Export file failed** entry appears in the log,
    and no partial file is left in the chosen folder.

## Accessibility and orientation

20. [ ] Turn the phone sideways with the Export sheet open: everything is reachable and
    nothing is cut off. Turn it back.
21. [ ] At the largest Larger Text size, the level names, face counts and the
    **Choose where to save…** button remain readable without clipping.
22. [ ] With VoiceOver on, each detail level reads as one item with its name, face count
    and purpose; the save button reads its label and hint.

## Result

- [ ] All passed — Bolt 3 confidence hypothesis holds: our simplifier and writers produce
  files that Fusion converts to a solid at true size.
- [ ] Something failed — describe it (and attach the exported log if possible).
