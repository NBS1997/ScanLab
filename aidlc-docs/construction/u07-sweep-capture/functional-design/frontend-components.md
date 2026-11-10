# Frontend Components — U07 Sweep Capture (with Explore additions)

Inputs: `mockups.md` (screens 1, 2, 3, 6), `mockups.html`, `interaction-spec.md` (states table, orientation), `accessibility-checklist.md` (A1, A4, A8, A11–A13), U07 `business-rules.md`.

| Component | Shows | Actions | States |
|---|---|---|---|
| LibraryView (changed) | **New scan** in the bottom bar; New scan also in "No scans yet" | Open New scan | Navigation now uses a path, so a saved sweep replaces New scan with the new Scan detail |
| NewScanView | "Capture method": Sweep and Photos cards with "use this for"; Tip about matt surfaces | Sweep opens Capture (full-screen, modal); Photos opens the photo screen via the `photoCapture` hook | Photos disabled with "Comes in the photo capture build" while the hook is nil |
| CaptureView | Full-screen camera with the reconstructed mesh as a wireframe; ✕ and "00:42 · Sweep" top; "12 areas · 34,560 faces" and Finish bottom; orange prompt near the top | Finish; ✕ (asks "Discard this capture?" once a surface exists) | Starting camera; capturing; saving ("Saving scan…"); failed: camera not allowed (Open Settings, Close), sweep unavailable (Close), nothing captured / not enough space / not saved (Try again, Close) |
| ExploreView (changed) | **Close range** chip and band menu (±2 / ±5 / ±10 cm) under the layer chips; legend titled "Close range ±5 cm" with mm ends; yellow "Move closer" / "Move back" badge under the centre ring | Toggle close range; choose band | Waiting for a reading (close range before any centre distance) |

Sideways: Capture keeps the picture full-screen with ✕ and timer top leading and stats
and Finish on the trailing edge; Explore's existing trailing layout gains the close-range
row.

Accessibility: the camera views are hidden from the screen reader. Close reads "Close"
with hint "Ends the capture without saving"; the timer reads "Sweep capture time, 42
seconds"; stats read "Captured, 12 areas · 34,560 faces"; Finish has a hint saying
when it becomes available. Photos (disabled) is a real button, so it reads as dimmed
with its reason. Close range has a hint; the band reads "plus or minus 5 centimetres";
the depth hint reads "Depth hint, Move closer" and is announced when it appears. The
tracking prompt is marked as frequently updating. Nothing flashes.
