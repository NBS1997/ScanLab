# Business Rules — U06 Live Sensor View

Inputs: `unit-of-work.md` (U06), `bolt-plan.md` (Bolt 4), `requirements.md` (FR-2.1, FR-2.2, NFR-6, NFR-7), `platform-verification.md` (V1, V2), `component-methods.md`, `component-dependency.md`, `decisions.md` (ADR-003, ADR-005, ADR-011), `design-system-mapping.md`, `interaction-spec.md`, `accessibility-checklist.md`.

| ID | Rule | Requirement |
|---|---|---|
| SR-1 | The live view needs world tracking with scene depth. If the phone does not support it, the screen says so and the event is logged as an error. | FR-2.1 |
| SR-2 | If camera permission is denied or restricted, the screen explains how to allow it in Settings, offers Open Settings, and logs a warning. | interaction-spec |
| SR-3 | The sensor has one holder at a time. Explore starts it when it appears and stops it when it disappears; start and stop are logged, the stop with frame count, duration and average rate. | component-dependency |
| SR-4 | Camera, Depth and Confidence toggle independently and in any combination; each change is logged. Edges is shown, disabled, with the reason "Coming in a later build". | FR-2.1 |
| SR-5 | Depth colours run warm (near, red) to cool (far, blue) over 0.2–5 m. Distances outside the range take the end colour; NaN, infinite, zero or negative readings are a see-through grey. A legend shows near and far when Depth is on. | design-system-mapping, A8 |
| SR-6 | Confidence colours: low red, medium amber, high green. An unknown value is grey. | FR-2.1 |
| SR-7 | Centre distance is the median of the central 5 × 5 depth pixels, skipping missing readings and low-confidence pixels. No valid pixel gives "—" ("No reading" to the screen reader). | FR-2.2 |
| SR-8 | Distances show in millimetres below 1 m and in metres (two decimals) from 1 m; a reading that rounds to 1,000 mm shows as metres. | FR-6.4 |
| SR-9 | Frame rate is measured over the latest 1 s of frame timestamps, shown on screen, and written to the log every 10 s while running. | NFR-7 |
| SR-10 | The distance and frame-rate text change at most four times a second. | NFR-6 |
| SR-11 | Overlays are turned to match the interface orientation, so they stay over the part of the picture they measured, upright and sideways. | NFR-6, A12 |
| SR-12 | Tracking-state changes, interruptions and session failures are logged. | project rule (diagnostics) |
