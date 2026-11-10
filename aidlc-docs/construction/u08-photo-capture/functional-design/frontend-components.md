# Frontend Components — U08 Photo Capture

Inputs: `mockups.md` and `mockups.html` (screens 2, 3, 4), `interaction-spec.md` (Capture, Scan detail states), `accessibility-checklist.md`, `stories.md` (US-07, US-11).

## Photo capture — `PhotoCaptureView`, `PhotoCaptureModel` (+ `PhotoCaptureModel+Building`)

Entry point for New scan › Photos (wired by the orchestrator at merge, into Bolt 6's
New scan screen): `PhotoCaptureView(environment: environment)`, presented full screen
(it has its own navigation bar with Close / Done).

| State | Shows |
|---|---|
| Preparing | "Starting camera…". Camera permission asked on first use. |
| Unfinished capture | Card: "N photos from <date>, using <size>, have not been built yet." **Build it now** / **Discard it**. |
| Capturing | Apple's `ObjectCaptureView` (box, dial, its own guidance) with a bar beneath: current advice ("Move slower"), photo count, and buttons by step — looking: **Find object**, **Start without box**; object found: **Start capture**; capturing: **Another pass** (after a full pass), **Finish**. **Cancel** always. |
| Finishing | "Saving the last photos…". |
| Building | Progress bar with "Building model: 42%", stage ("Now making the mesh"), time left, the 10 s still-working note, detail level, background note if any, and **Cancel** (keeps photos). A note says switching apps is fine and recorded in Diagnostics. |
| Saving | "Saving the scan…". |
| Keep question | "Keep the raw capture?", photo count and storage, detail level, **Keep (412 MB)** and **Discard**. |
| Done | "Photo scan saved", "Saved “…”. Raw capture kept (412 MB)." and the detail level; **Done**. |
| Failed | Reason and next step; **Build again** when photos are kept; **Discard capture** when photos are on disk; **Done**. |
| Cancelled | "The photos are kept." with Build again, or "The capture was removed."; **Done**. |

Close mid-build asks "Stop building?" (Stop and close / Keep building). The screen
watches the app's scene phase for the background observation (PC-11).

## Scan detail — one added row

| Part | Behaviour |
|---|---|
| Export raw capture… | Shown under "Raw capture" only when the scan has a kept raw capture. Packs a zip ("Packing raw capture…"), then the phone's save chooser. Result or failure (reason and next step) shown in place under the row. Hint names the size. |

The Export sheet's raw-capture switch from the mockups is not used: the export is a
separate row on Scan detail (owner's Bolt 7 brief), leaving the mesh Export sheet as it is.

## Accessibility

- Every button has a label and a hint (what happens to the photos).
- The progress bar is one element: "Building model", value "42 percent, now making the
  mesh, about 3 min left".
- The photo count reads "Photos taken: N"; advice text is marked as updating.
- Decorative symbols are hidden from VoiceOver. Text wraps; nothing is fixed-size.
