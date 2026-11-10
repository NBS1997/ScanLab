# On-Device Checklist — Bolt 4, Live Sensor View

Build: ScanLab 0.1.x, delivered through TestFlight (group "Owner").
Covers story US-03 (FR-2.1, FR-2.2, NFR-7) and accessibility checks A1, A4, A8, A11,
A12, A13. Tick each item on the phone. Anything that fails: note what you saw, and
export the log from Diagnostics if you can.

You need: a tape measure and a flat wall with some texture (not a mirror or glass).

## Open Explore

1. [ ] On **Scans**, **Explore** is at the top right and **Diagnostics** still at the
   top left. Tap **Explore**.
2. [ ] On first use, iOS asks to use the camera. Tap **Allow**.
3. [ ] "Starting camera" shows briefly, then the live camera picture fills the screen
   with a small white ring at the centre.
4. [ ] The top panel shows a distance (for example "845 mm" or "1.32 m") with "at
   centre", and a frame rate such as "60 fps".

## Layers (FR-2.1)

5. [ ] Bottom bar shows **Camera** (on), **Depth**, **Confidence** and **Edges**.
   **Edges** is greyed out and cannot be turned on; "Edges: coming in a later build" is
   shown beneath.
6. [ ] Depth alone: turn Camera off, Depth on. Near things are red/orange, far things
   blue; areas with no reading are grey. A legend shows **Near 0.2 m** and **Far 5 m**.
7. [ ] Confidence alone: Depth off, Confidence on. Red/amber/green areas, with a
   Low/Medium/High legend. Edges of objects and dark or shiny surfaces tend to be red.
8. [ ] Camera alone: Confidence off, Camera on. Plain camera picture, no legend.
9. [ ] Camera + Depth, Camera + Confidence, Depth + Confidence, and all three: each
   combination shows, the picture keeps moving, and the overlay sits over the right
   objects (hold a hand in front: its colour patch lines up with the hand).
10. [ ] All three off: black screen, readouts still updating.

## Distance at centre (FR-2.2) — record as an S3 finding

11. [ ] Tape-measure **1.00 m** from a wall to the back of the phone (the camera end).
    Hold the phone square to the wall, ring on the wall.
    - Reading shown: ________ Error (reading − 1.00 m): ________
    - Repeat at 0.50 m: ________ and 2.00 m: ________ (optional)
12. [ ] Point at the sky or far away (beyond 5 m): the reading shows "—" or a large
    value, and the app does not stall.

## Frame rate (NFR-7)

13. [ ] With all three layers on, the frame rate shown is ________ fps (target: 30 or
    more). The picture looks smooth.
14. [ ] Stay on Explore for at least 25 seconds. Open **Diagnostics**: there are
    **Frame rate** entries about every 10 seconds, with the fps value. Record one:
    ________

## Orientation (A12)

15. [ ] Turn the phone sideways (both ways). The picture stays full-screen, the layer
    buttons move to the right-hand edge, and the depth overlay still lines up with the
    objects behind it (check with a hand). Turn back upright: same.

## Leaving the screen releases the sensor

16. [ ] Go back to **Scans**, then open **Diagnostics**. Newest entries include
    **Sensor session started**, **First frame received**, **Explore layer changed**
    (one per toggle), **Explore left** and **Sensor session stopped** (with frames,
    seconds and average fps). Record the average fps: ________
17. [ ] The green camera-in-use dot at the top of the screen goes away after leaving
    Explore.
18. [ ] Open Explore, press the Home gesture to leave the app, return. The picture
    resumes (a "camera is paused" message may show briefly); the log shows **Sensor
    session interrupted** and **Sensor session resumed**.

## Permission refused

19. [ ] Settings › ScanLab › turn **Camera** off. Open Explore: "Camera not allowed"
    explains how to allow it, with **Open Settings**. Tapping it opens ScanLab's
    settings page. Turn Camera back on and return; go back and reopen Explore: the
    picture works. Diagnostics shows **Camera permission denied**.

## Accessibility

20. [ ] VoiceOver on, on Explore: swipe through. The distance is read as "Distance at
    centre, … millimetres/metres"; the frame rate as "Frame rate, … frames per second";
    each button as "Camera layer", "Depth layer"… with on/off; Edges is read as dimmed
    with "Coming in a later build". With Depth on, the legend is read as text (A8).
21. [ ] Largest text size (Settings › Accessibility › Display & Text Size › Larger
    Text): the panel and buttons are readable and not cut off (buttons may wrap into
    two rows). Set it back.
22. [ ] Reduce Motion on: nothing flashes or animates distractingly (A13).

## Result

- [ ] All passed — Bolt 4 accepted. Findings recorded: 1.00 m reading and error, fps.
- [ ] Something failed — describe it (and attach the exported log if possible).
