# Frontend Components — U06 Live Sensor View

Inputs: `mockups.md` (screen 6), `interaction-spec.md`, `design-system-mapping.md`, `accessibility-checklist.md` (A1, A4, A8, A11–A13), `requirements.md` (FR-2.1, FR-2.2, NFR-6, NFR-7).

| Component | Shows | Actions | States |
|---|---|---|---|
| LibraryView (changed) | Explore button, top trailing; Diagnostics stays top leading | Open Explore | — |
| ExploreView | Full-screen camera; depth and confidence overlays; centre ring; distance at centre; frame rate; legends for the layers that are on | Toggle Camera, Depth, Confidence; Edges disabled ("Coming in a later build") | Starting camera; permission refused (Open Settings); unsupported; failed; paused |
| LiveLayers | Camera (ARSCNView), then depth, then confidence, aspect-filled to the same rectangle | — | Camera hidden: black under the overlays |
| ReadoutPanel | Distance ("845 mm" / "1.02 m"), "at centre", "60 fps", legends | — | No reading: "—" |
| LayerControls | Four toggle chips; bottom when upright, trailing edge when sideways; 2 × 2 grid if a row does not fit | Toggle | Edges disabled |

Accessibility: each chip reads "<Layer> layer" with its on/off state; Edges has the
hint "Coming in a later build". Distance reads as "Distance at centre, 1.02 metres";
frame rate as "Frame rate, 60 frames per second". Legends are read as text. The camera
picture and overlays are hidden from the screen reader. Nothing flashes.
