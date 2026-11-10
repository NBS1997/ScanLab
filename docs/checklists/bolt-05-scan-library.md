# On-Device Checklist — Bolt 5, Scan Library

Build: ScanLab 0.1.x, delivered through TestFlight (group "Owner").
Covers story US-10 (FR-6.1–6.4, NFR-8, NFR-9) and accessibility checks A1, A4, A6, A9,
A11, A12. Tick each item on the phone. Anything that fails: note what you saw, and
export the log from Diagnostics if you can.

Scanning itself arrives in later builds, so this build fills the library with the
built-in sample model (a 60 × 40 × 20 mm stepped block).

## Empty library

1. [ ] Open ScanLab. **Scans** shows "No scans yet", mentioning Diagnostics and the
   sample model. **Diagnostics** is at the top left, **Explore** at the top right.

## Add the sample twice

2. [ ] Tap **Diagnostics**. Under **Sample model** there are **Export sample model…**
   and **Add sample to library**.
3. [ ] Tap **Add sample to library**. Within a few seconds a green line says
   "Added “Sample 11 Nov 14:05” to the library" (with today's date and time).
4. [ ] Wait until the minute changes, then tap it again. A second line appears with the
   new time.
5. [ ] Under **Activity**, two **Scan added** entries show `method: sample`,
   `faces: 19840` and a byte count.

## The list (FR-6.1)

6. [ ] Go back to **Scans**. Both scans are listed, **newest first**.
7. [ ] Each row shows: a **thumbnail** of the grey stepped block on a dark tile, seen
   from above and to the right; the **name**; and "**Sample · 11 Nov · 500 KB**" or
   similar (method, date, size on the phone).
8. [ ] There is **no** green tick on either row (no accuracy reports yet).
9. [ ] Pull the list down: it refreshes and nothing changes.

## Scan detail (FR-6.4)

10. [ ] Tap the newest scan. The title is its name on one line. "Opening model…" shows
    briefly, then the block appears, seen from in front, to the right and above.
11. [ ] Drag: the block turns. Pinch: it zooms in and out. Two-finger drag: it moves.
    Tap the **Reset view** button (circular arrow, top right of the model): the view
    returns to the start.
12. [ ] Chips under the model: **Shape** (on) and **Edges** (greyed out), with "Edges:
    coming in a later build". Turning Shape off hides the model; on shows it again.
13. [ ] Details: **Method** Sample, **Size** 60.0 × 40.0 × 20.0 mm, **Faces** 19,840 faces,
    **Raw capture** None, **On this phone** about 500 KB, **Saved** today.
14. [ ] Bottom bar: **Check accuracy** is greyed out; the footer says "Check accuracy:
    comes with the accuracy report". **Export** is available.

## Export from detail

15. [ ] Tap **Export**. The Export sheet opens with the scan's name, size 60.0 × 40.0 ×
    20.0 mm and 19,840 faces. Choose Fusion-friendly, STL, **Choose where to save…**
    and save to iCloud Drive. Close the sheet; you are back on Scan detail.

## Rename (FR-6.2)

16. [ ] Tap **•••** (top right) › **Rename**. Type "Stepped block A" and **Save**. The
    title changes.
17. [ ] Try renaming to only spaces: a red message says the name cannot be empty, and
    the old name stays.
18. [ ] Go back: the list shows the new name. On the other scan, touch and hold ›
    **Rename** › "Stepped block B" › **Save**.
19. [ ] **Force-quit** ScanLab and reopen it. Both new names are still there.

## Delete (FR-6.2, NFR-9)

20. [ ] Swipe left on "Stepped block B" › **Delete**. A confirmation asks
    "Delete “Stepped block B”?" and says the model will be removed, **freeing about
    500 KB**, and that it cannot be undone. Tap **Delete scan**. The row disappears.
21. [ ] Open "Stepped block A" › **•••** › **Delete** › **Delete scan**. The screen
    closes and the list is empty: "No scans yet" is back.
22. [ ] Settings › General › iPhone Storage › ScanLab: "Documents & Data" has shrunk
    accordingly (it may take a minute to update).

## Survives an update (FR-6.3, NFR-8)

23. [ ] Add the sample to the library again and rename it "Survivor".
24. [ ] **On the next TestFlight build after this one** (the owner tests this item then):
    install it over this build without deleting the app. "Survivor" is still listed,
    opens in Scan detail, and has the same thumbnail and size.

## Accessibility and orientation

25. [ ] Turn the phone sideways on Scans and on Scan detail. On Scan detail the model
    sits on the left and the details on the right; nothing is cut off. Turn it back.
26. [ ] Set the largest text size (Settings › Accessibility › Display & Text Size ›
    Larger Text). Rows, details and the bottom bar remain readable. Set it back.
27. [ ] With VoiceOver on: a row reads its name, method, date and size; swiping up or
    down on a row offers **Rename** and **Delete** actions. On Scan detail the model
    reads "3D model, 60.0 × 40.0 × 20.0 mm, 19,840 faces"; "More actions", "Check
    accuracy" (dimmed, with its reason) and "Export" are read with sensible labels.

## Diagnostics log

28. [ ] In Diagnostics › Activity there are entries for **Library shown**, **Scan added**,
    **Scan detail shown**, **Scan renamed**, **Scan deleted** (with bytes), **Export
    opened from scan**, and no errors.

## Result

- [ ] All passed — approve Bolt 5 (item 24 is confirmed on the following build).
- [ ] Something failed — describe it (and attach the exported log if possible).
