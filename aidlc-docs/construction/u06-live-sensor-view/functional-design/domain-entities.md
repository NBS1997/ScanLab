# Domain Entities — U06 Live Sensor View

Inputs: `unit-of-work.md` (U06), `component-methods.md` (`SensorFeeding`), `platform-verification.md` (V1), `decisions.md` (ADR-003).

All in `Packages/ScanLabCore/Sources/ScanLabCore/Sensors/`, Foundation only.

| Entity | Kind | Holds | Notes |
|---|---|---|---|
| `DepthFrame` | value | width, height, `depths` [Float] in metres, `confidence` [UInt8] 0/1/2 (may be empty), timestamp | Failable init rejects mismatched sizes. Sensor orientation, row-major, top row first |
| `ConfidenceLevel` | enum | low 0, medium 1, high 2 | Ordered; has a display name |
| `SensorFrame` | value | timestamp, optional `DepthFrame` | No camera image: the app draws it directly |
| `SensorStatus` | enum | starting, running, interrupted, stopped, permissionDenied, unsupported(reason), failed(reason) | User-facing `message`; `blocksView` |
| `SensorStreams` | value | `frames` and `statuses` async streams | Separate so status changes are never dropped behind frames |
| `SensorFeeding` | port | `start() -> SensorStreams`, `stop()` | Main-actor methods; adapter `LiveSensorFeed` in the app |
| `RGBAColour`, `RGBAImage`, `QuarterTurn` | values | 8-bit colour; RGBA bytes; quarter-turn rotation | `rotated` turns overlays to the interface orientation |
| `DepthColourMap`, `LegendStop` | value | near/far range (default 0.2–5 m), six-colour ramp, invalid grey | `legendStops(count:)` |
| `ConfidenceColourMap` | value | colour per level | |
| `CentreSampler` | functions | — | Median of the central window |
| `FrameRateMeter` | value | timestamps in a 1 s window | Handles gaps and late timestamps |
| `OverlayRenderer` | functions | — | Depth or confidence frame to `RGBAImage` |
| `ReadoutText` | functions | — | mm/m distance, fps, spoken forms, legend labels |

Deviation from `component-methods.md`: the port does not expose `centreDistance` and
`frameRate`; the screen's model derives them from frames with `CentreSampler` and
`FrameRateMeter`, which keeps that logic in Core and tested.
