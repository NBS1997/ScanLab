# Business Rules — U07 Sweep Capture (with Explore additions)

Inputs: `unit-of-work.md` (U07), `bolt-plan.md` (Bolt 6, including "Added 2026-11-11"), `requirements.md` (FR-2.1, FR-2.2, FR-3.1–3.3, NFR-6, NFR-9), `stories.md` (US-03, US-06), `component-methods.md` (CaptureSession, `SweepCapturing`), `decisions.md` (ADR-003, ADR-005, ADR-011), `interaction-spec.md`, `mockups.md` (screens 2, 3, 6), `accessibility-checklist.md`.

## Sweep capture

| ID | Rule | Requirement |
|---|---|---|
| SC-1 | A capture moves idle → preparing → capturing → finishing → saved, and can end failed or cancelled. Any other step is refused, logged as "Capture step ignored", and changes nothing. | FR-3.1 |
| SC-2 | Capturing begins with the camera's first picture. Finish is available only while capturing and once some surface exists. | FR-3.1 |
| SC-3 | Close before Finish cancels: the camera stops and nothing is saved. If a surface has been captured, Close first asks "Discard this capture?". Close is not available while saving. | interaction-spec |
| SC-4 | Finish pauses the camera, merges every reconstructed piece into one mesh in world positions, joins corners closer than 0.5 mm, and drops faces with missing corners or no area. | FR-3.1 |
| SC-5 | The merged mesh is y-up from the platform; it is turned z-up (`Mesh.convertedFromYUp()`) before saving, so every scan is upright in the library and in exports. | FR-3.1, FR-7 |
| SC-6 | A finished sweep is saved to the library at once, as method Sweep, with the default name "Sweep d MMM HH:mm"; the screen then opens its Scan detail. No save step. | FR-3.2 |
| SC-7 | An empty capture saves nothing and says so ("Nothing captured … nothing was saved"). | FR-3.1 |
| SC-8 | Not enough storage saves nothing and says so (`StoreError.noSpace` → "Not enough space"). | NFR-9 |
| SC-9 | No LiDAR / no scene reconstruction: "Sweep unavailable" with the reason. Camera refused: "Camera not allowed" with Open Settings. A session failure ends the capture with the reason. Each is logged. | interaction-spec |
| SC-10 | Limited tracking shows a plain prompt (starting, slow down, too little detail, finding your place, lost); an interruption shows the paused message. The capture continues. | FR-3.1 (guidance proper is U09) |
| SC-11 | Rotating the phone never stops a capture; controls move to the trailing edge when sideways. | FR-3.3 |
| SC-12 | Start, first frame, tracking changes, finishing, assembly counts, saved, cancelled and not-saved (with reason) are logged under `capture`; screen shows under `ui`. | project rule (diagnostics) |
| SC-13 | New scan lists Sweep and Photos. Until the photo capture build is merged, Photos is shown disabled with "Comes in the photo capture build". | US-07 (deferred to U08) |

## Explore additions (owner feedback 2026-11-11)

| ID | Rule | Requirement |
|---|---|---|
| EX-1 | Close range spreads the full depth colour ramp over centre ± half-width (default ±5 cm; ±2 or ±10 cm on request). Beyond the band, the end colours. Turning it on also turns the Depth layer on. | US-03, FR-2.1 |
| EX-2 | The band centres on the centre distance and moves only when the reading drifts more than half the half-width away, so colours do not shimmer. Missing readings leave it in place. Before any reading, the legend says it is waiting. | US-03 |
| EX-3 | The close-range legend shows its ends in millimetres and the band in its title ("Close range ±5 cm"). | A8 |
| EX-4 | The poor-depth hint looks at the central 11 × 11 depth pixels. No readings: "Move back" if the last good reading was under 30 cm, otherwise "Move closer". Median under 20 cm: "Move back". Otherwise poor when ≥ 30% of pixels are missing or ≥ 50% of readings are low-confidence: poor under 30 cm "Move back", poor elsewhere "Move closer". Not poor: no hint. **All thresholds are first guesses**, to be tuned on the phone. | US-03 (Bolt 10/11 extend) |
| EX-5 | A new hint shows only after it has held for 0.75 s; it is announced to VoiceOver when it appears. | NFR-6 |
| EX-6 | Colour mode changes, band changes and hint changes (not every frame) are logged under `ui`. | project rule (diagnostics) |
