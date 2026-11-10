# On-Device Checklist — Bolt 7, Photo Capture

Build: ScanLab 0.1.x, delivered through TestFlight (group "Owner").
Covers story US-07 (FR-4.1–4.4, FR-6.6), the raw-capture part of US-11 (FR-7.5),
requirements Open Question 3 (building in the background), NFR-2, NFR-9, and
accessibility checks A1, A4, A6, A9, A11, A12. Tick each item on the phone. Anything
that fails: note what you saw, and export the log from Diagnostics if you can.

Build 4 contains Bolts 6, 7 and 8: open the photo screen from **Library › New scan ›
Photos** (it opens full screen). Items 26–29 (raw-capture export) need a photo scan
whose raw capture was kept.

**Known risk:** Apple's developer forum has reports (iOS 26.4–26.5) of Object Capture
failing on iPhone 17 Pro models with a "sensor failure" or a build error. If that
happens here, record the exact message from the screen and the Diagnostics log: it is
a finding, not a ScanLab bug to work around.

You need: a small fitting under 150 mm (matte, not shiny or see-through), a plain
table with some texture, good even light, calipers, the PC with Fusion, and the printed
reference object if you have it.

## Start a photo scan

1. [ ] Turn on **aeroplane mode** (NFR-2: everything below works offline).
2. [ ] Library › **New scan** › **Photos**. The first time, the phone asks to use the
   camera: tap **Allow**. "Starting camera…" shows, then Apple's capture view.
3. [ ] Put the fitting on the table and point at it. A box appears round it (if not,
   the bar says "Put the object on a flat surface…"; tap **Find object**). Tap
   **Start capture**.
4. [ ] Walk slowly all the way round. Photos are taken automatically; the bar counts
   "N photos". Advice such as "Move slower" appears when it applies.
5. [ ] When the dial is full, **Another pass** appears. Do one more pass lower down,
   then tap **Finish**. "Saving the last photos…" shows briefly.

## Building with progress (FR-4.3, FR-4.2)

6. [ ] The screen changes to **Building model: N%** with a bar, "Now …" (the stage,
   e.g. "Now making the mesh") and, when the phone estimates it, "About N min left".
7. [ ] The percentage moves at least every 10 seconds, or a line says "Still working.
   Last update N s ago." Note roughly how long the whole build takes: ____ min.
8. [ ] Under the bar: **Detail level: reduced (the only level iPhone offers)**.

## Building in the background (Open Question 3)

9. [ ] While it is building (say at 20–40%), go to the Home Screen and open another
   app for about **2 minutes**, then come back to ScanLab.
10. [ ] A line with a moon symbol says one of: "Away N s: building carried on (a% →
    b%)", "building paused (stayed at a%)", "the model finished building in the
    background", or "building failed in the background". Record which: __________
11. [ ] If it failed: **Build again** is offered. Tap it; it completes without
    capturing again (it may start from where the phone saved its work).

## Keep or discard the raw capture (FR-6.6)

12. [ ] After building, "Saving the scan…" shows, then **Keep the raw capture?** with
    "The N photos and camera positions use NNN MB…". The size is plausible (roughly
    3–5 MB per photo). Size shown: ______
13. [ ] Tap **Keep (NNN MB)**. "Photo scan saved" shows "Saved “Photos 11 Nov 14:05”.
    Raw capture kept (NNN MB)." and the detail level. Tap **Done**.

## The scan (FR-4.1, FR-4.4, FR-6.4)

14. [ ] The library lists the new scan, method Photos, with a size that includes the
    raw capture.
15. [ ] Open it. The model stands **upright** (as it sat on the table, not on its side)
    and turns and zooms.
16. [ ] Details: **Method** "Photos · reduced detail"; **Raw capture** "Kept · NNN MB";
    **On this phone** is about the model plus the raw capture.
17. [ ] **Size**: measure the fitting with calipers in the same three directions.
    App: ________ mm. Calipers: ________ mm. Each within a few mm (the exact accuracy
    is judged later, in Bolt 8). If it is off by a factor (×10, ×1000), say so.

## Export to Fusion (US-11)

18. [ ] **Export** › Fusion-friendly › STL › **Choose where to save…** › iCloud Drive.
19. [ ] On the PC, Fusion › Insert Mesh: it opens at the same size as the app shows,
    upright with Z up.

## Discard path

20. [ ] Do a second, quick photo scan of the same fitting. At **Keep the raw
    capture?** tap **Discard**. The message says "Raw capture discarded."
21. [ ] Its Scan detail shows **Raw capture** None and no "Export raw capture…" row; its
    size on the phone is only the model.

## Delete frees the raw capture (NFR-9)

22. [ ] On the scan with a kept raw capture, check Settings › General › iPhone Storage
    › ScanLab "Documents & Data". Then delete a photo scan with a kept raw capture in
    ScanLab: the confirmation says "The model and its raw capture will be removed…,
    freeing NNN MB". Afterwards Documents & Data has shrunk by about that much (it may
    take a minute). (Do this last if you want to keep the scan for items 26–29.)

## Error cases

23. [ ] **Cancel mid-build:** start a photo scan, finish it, and while building tap
    **Cancel**. "Cancelled — The photos are kept." with **Build again**. Tap **Discard
    capture**, then **Done**.
24. [ ] **Close mid-build:** start another, and while building tap **Close**: "Stop
    building?" appears. Tap **Stop and close**. Open Photos again: **Unfinished
    capture** offers **Build it now** / **Discard it**. Build it: it completes without
    capturing again.
25. [ ] **Camera refused:** Settings › Privacy & Security › Camera › ScanLab off. Open
    Photos: "ScanLab is not allowed to use the camera. Allow it in Settings…" Turn it
    back on.
    Optional: tap **Finish** after only a few photos: "Only N photographs were taken;
    at least 10 are needed."

## Export the raw capture (FR-7.5)

26. [ ] Open the scan whose raw capture was kept. Under Raw capture tap **Export raw
    capture…**. "Packing raw capture…" shows, then the save chooser. Save to iCloud
    Drive. A line says "Saved <name> raw capture.zip."
27. [ ] On the PC, unzip it: a folder with **Images/** holding every photo (HEIC; count
    matches item 12), **camera-positions.csv** and **README.txt**.
28. [ ] camera-positions.csv opens in a spreadsheet: one row per photo with an image
    name, x/y/z in metres and four rotation numbers (lens columns may be filled too).
29. [ ] Optional: Export raw capture again and tap **Cancel** in the chooser: nothing is
    saved and the screen stays usable.

## Reference object (if printed)

30. [ ] Photo-scan the printed reference object the same way and keep the raw capture.
    Its overall size in the app against the measurement sheet: ________ (this is the
    input Bolt 8 uses).

## Accessibility and orientation

31. [ ] With VoiceOver on, during building the bar reads "Building model, 42 percent,
    now making the mesh, about 3 min left" (or similar); **Cancel**, **Keep (…)**,
    **Discard**, **Build again** and **Export raw capture…** are read with their hints.
32. [ ] At the largest text size the building, keep and finished screens are readable
    and nothing is cut off. Turning the phone sideways keeps everything usable.

## Diagnostics log

33. [ ] Diagnostics › Activity has `photo` entries: **Photo capture opened**, **Camera
    permission asked**, **Capture started**, **Taking photos**, **Capture completed**
    (images), **Build started**, several **Build progress** (percent, stage),
    **Build request finished**, **Build finished** (route `obj` or `usdz-modelio`,
    positions, seconds), **Photo scan saved** (faces, size), **Raw capture kept** /
    **Capture discarded**, **App left during build** and **Background build observed**
    (seconds, before, after, advanced), **Raw capture zip written**, **Raw capture
    exported**; and **Cancel tapped**, **Build cancelled**, **Photo capture failed**
    for the error cases. Note the route: ______. Any **Model size unexpected** or
    **OBJ output failed; trying USDZ** entries: note them.

## Result

- [ ] All passed — approve Bolt 7.
- [ ] Something failed — describe it (and attach the exported log if possible).
