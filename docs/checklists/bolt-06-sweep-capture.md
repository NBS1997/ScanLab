# On-Device Checklist — Bolt 6, Sweep Capture

Build: ScanLab 0.1.x, delivered through TestFlight (group "Owner").
Covers story US-06 (FR-3.1–3.3, NFR-9), US-03 additions from the owner's feedback of
11 Nov (close-range colours, poor-depth hint) and accessibility checks A1, A4, A11, A12.
Tick each item on the phone. Anything that fails: note what you saw, and export the log
from Diagnostics if you can.

You need: a subject at least 0.5 m across (a section of the kayak hull, or a chair), a
tape measure, the TV remote on the sofa arm, and Fusion on the PC.

## Scans from build 3 survive the update (carried over from Bolt 5, item 24)

1. [ ] Install this build over the previous one **without deleting the app**. Every scan
   from build 3 (including "Survivor", if you made it) is still listed, opens in Scan
   detail, and has the same thumbnail and size.

## New scan

2. [ ] On **Scans**, a **New scan** button sits in the bottom bar. Tap it: **New scan**
   opens with "Capture method", **Sweep** ("Larger things, 15 cm and up…") and
   **Photos** ("Small parts, finer detail…"), and a **Tip** about matt, light-coloured
   surfaces.
3. [ ] **Photos** is greyed out and says "Comes in the photo capture build". Tapping it
   does nothing. *(Once the photo capture build is merged, Photos opens its screen
   instead; skip this item then.)*
4. [ ] Go back. If the library is empty (or later, after deleting every scan), "No
   scans yet" shows its own **New scan** button, which also opens New scan.

## Sweep a subject (FR-3.1, FR-3.2)

5. [ ] Tap **Sweep**. The first time, the camera permission prompt appears (if it has
   not already for Explore); allow it. "Starting camera" shows briefly, then the camera
   picture fills the screen with **✕** and "00:00 · Sweep" at the top, "No surface yet"
   and a greyed-out **Finish** at the bottom.
6. [ ] Stand about 0.5–1 m from the kayak hull section (or chair). Move slowly. A
   coloured wireframe mesh appears over the surfaces and grows as you move; the timer
   counts up; the stats read like "6 areas · 21,400 faces" and rise. **Finish** becomes
   available once a surface appears.
7. [ ] Move the phone quickly: an orange prompt "Slow down." appears, then goes once you
   slow down. (Other prompts may appear while tracking starts or after covering the
   camera; each should make sense.)
8. [ ] Turn the phone sideways **during** the capture (FR-3.3). The capture continues;
   the timer keeps counting; ✕ stays top left and Finish moves to the trailing edge.
   Turn back upright.
9. [ ] Cover the whole subject, then tap **Finish**. "Saving scan…" shows, then the
   **Scan detail** of the new scan opens directly. Its name is like "Sweep 11 Nov
   14:05" and its method is **Sweep**.
10. [ ] **Upright check:** in Scan detail the subject stands the right way up — the
    floor is at the bottom, not lying on its side or upside down.
11. [ ] Note the **Size** and **Faces**. Measure the subject's longest side with the
    tape measure: ______ mm on the tape, ______ in the app. They should agree to within
    a few centimetres (sweep is room-scale, ADR-005).
12. [ ] Tap **Back**: the Scans list shows the new scan at the top, with a thumbnail of
    the subject, and **without any save step** (FR-3.2).

## Into Fusion (Bolt DoD)

13. [ ] On the new scan, **Export** › Fusion-friendly › STL › save to iCloud Drive.
14. [ ] On the PC, insert the STL into Fusion (Insert › Insert Mesh, units millimetres).
    It is **upright** (z up) and its size matches item 11.
15. [ ] Mesh › Prepare › Repair, then Modify › Convert Mesh to a solid (Faceted or
    Prismatic). Note whether it converts: ______. A sweep is an open surface, so
    Fusion may need the repair step or refuse; record what happened either way.

## Cancel, empty capture and errors

16. [ ] Start a sweep, let some mesh appear, tap **✕**. "Discard this capture?" appears.
    Tap **Keep capturing**: the capture carries on. Tap ✕ again › **Discard**: you are
    back on New scan, and the Scans list has **no new scan**.
17. [ ] Start a sweep and tap ✕ before any mesh appears: it closes at once, no question.
18. [ ] Start a sweep with your hand **covering the camera**. A tracking prompt appears
    and no mesh grows; Finish stays greyed out. (If any surface does appear and you can
    tap Finish with almost nothing, "Nothing captured" may show instead: it must say
    nothing was saved, and the library must have no new scan.)
19. [ ] *(Optional, only if the phone is nearly full)* With less than a few MB free, a
    sweep's Finish shows "Not enough space … nothing was saved", and no scan is added.
20. [ ] Settings › Privacy & Security › Camera › turn ScanLab **off**. Start a sweep:
    "Camera not allowed" with **Open Settings** and **Close**. Open Settings works;
    turn Camera back on.

## Explore: close-range colours (owner feedback)

21. [ ] Open **Explore**. Below the layer chips there is a **Close range** chip. Tap it:
    the **Depth** layer turns on and the legend title reads "Close range ±5 cm", with
    Near and Far shown in millimetres (for example "Near 745 mm · Far 845 mm").
22. [ ] **The remote on the sofa arm:** aim the centre ring at the remote from about
    0.5–1 m. In close range the remote stands out from the sofa arm as a clearly
    different colour (in standard colours it was nearly the same as the arm). Write what
    you saw: ______.
23. [ ] Tap the **±5 cm** button and choose **±2 cm**: the colour change gets sharper
    (and wraps to the end colours sooner). Choose **±10 cm**: gentler. Move the phone
    nearer and farther: the band follows the centre distance after a moment, without
    shimmering while you hold still.
24. [ ] Turn **Close range** off: the standard 0.2–5 m colours and legend return.

## Explore: poor-depth hint (owner feedback)

25. [ ] With the phone **very close** (under about 20 cm) to a surface, a yellow
    **"Move back"** hint appears just below the centre ring within a second.
26. [ ] Point at something **far away** and dark, or across the room at a dark doorway
    or window: **"Move closer"** appears.
27. [ ] Point at the **dark remote** from about 1 m: if the centre reading is patchy,
    "Move closer" appears; moving to about 40 cm should clear it. Write what you saw:
    ______. (The thresholds are first guesses; your notes will tune them.)
28. [ ] At a normal distance from a plain, light wall: no hint. The hint never flickers
    on and off rapidly.

## Orientation and accessibility

29. [ ] Turn the phone sideways on New scan, Capture (done in item 8) and Explore with
    Close range on. Nothing is cut off; the close-range controls stay readable.
30. [ ] With **VoiceOver** on: New scan reads "Sweep… button" and "Photos… dimmed" with
    its reason; Capture reads "Close", "Sweep capture time", "Captured, 6 areas…",
    and "Finish"; Explore reads "Close range" with its hint, "Band width, plus or minus
    5 centimetres", and the hint is announced ("Move closer") when it appears.
31. [ ] Set the largest text size: New scan, Capture and Explore remain readable. Set it
    back.

## Diagnostics log

32. [ ] Diagnostics › Activity shows entries for: **New scan shown**, **Capture method
    chosen** (sweep), **Capture started**, **Sweep session started**, **First frame
    received**, **Tracking changed**, **Capture finishing**, **Sweep mesh assembled**
    (parts, welded, faces), **Scan added** (method sweep), **Capture saved**;
    **Capture cancelled** for item 16; **Capture not saved** for items 18–20 if
    triggered; **Explore colour mode changed**, **Explore close-range band changed** and
    **Depth hint changed** (only when the hint actually changes, not every frame).

## Result

- [ ] All passed — approve Bolt 6.
- [ ] Something failed — describe it (and attach the exported log if possible).
