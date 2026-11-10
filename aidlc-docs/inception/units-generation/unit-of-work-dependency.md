# Unit Dependencies — ScanLab (LidarApp)

Inputs: `unit-of-work.md`, `component-dependency.md`, `components.md`, `services.md`,
`component-methods.md`, `decisions.md`, `requirements.md`, `stories.md`. Topology only;
the order of work is chosen in Delivery Planning.

## Dependency Graph

"A → B" means A depends on B (B must exist first).

| Unit | Depends on | Why |
|---|---|---|
| U01 Delivery skeleton | — | |
| U02 Diagnostics log | U01 | Needs the app, Core package and Diagnostics screen |
| U03 Reference object | — | Separate script; no app code |
| U04 Geometry and export | U01, U02 | Core package; logs export events |
| U05 Scan library | U04 | Stores and displays `Mesh`; reads mesh files |
| U06 Live sensor view | U01, U02 | App and logging |
| U07 Sweep capture | U05, U06 | Saves to the library; shares the sensor session handling |
| U08 Photo capture | U05 | Saves to the library; OBJ reading from U04 via U05 |
| U09 Guidance and interruption | U07, U08 | Adds to both capture methods |
| U10 Accuracy stage 1 | U03, U05 | Bundled feature table and reference mesh; reads scans |
| U11 Accuracy stage 2 | U10 | Builds on alignment and the report model |
| U12 Edge detection | U06, U05 | Layer on Explore and on Scan detail |
| U13 Hardware details | U06 | Shares the sensor and camera discovery |

```
U01 ──> U02 ──> U04 ──> U05 ──┬──> U07 ──┐
  │      │                    │          ├──> U09
  │      └──> U06 ────────────┼──> U07   │
  │            ├──> U12 <─────┤          │
  │            └──> U13       ├──> U08 ──┘
  │                           └──> U10 ──> U11
U03 ──────────────────────────────> U10
```

Arrows here point in build order (from prerequisite to dependant).

Text fallback: U01 comes first, then U02. From U02, two branches: U04 then U05, and U06.
U05 feeds U07, U08, U10 and U12. U06 feeds U07, U12 and U13. U07 and U08 both feed U09.
U03 stands alone and feeds U10, which feeds U11.

**Cycle check:** none. Every dependency points to a Unit with a smaller position in the
layering below.

## Layers (every Unit's prerequisites are in earlier layers)

| Layer | Units |
|---|---|
| 0 | U01, U03 |
| 1 | U02 |
| 2 | U04, U06 |
| 3 | U05, U13 |
| 4 | U07, U08, U10, U12 |
| 5 | U09, U11 |

## Parallel Development Opportunities

Units with no path between them may be built at the same time:

- **U03** with anything — it touches only `reference-object/`.
- **U04 and U06** — Core geometry versus the sensor feed.
- **U13** with U05 and with everything in layer 4.
- **U07, U08, U10 and U12** — once U05 and U06 exist, all four are independent of each
  other. U07 and U08 both edit the New scan and Capture screens; they must agree that
  screen's shape first (see Integration Points).
- **U09 and U11** — independent of each other.

## Integration Points

| Between | Contract | Kind |
|---|---|---|
| Every Unit → U02 | `Logging` port, `LogEvent` | Shared interface |
| U05 ↔ U04 | `Mesh`, `MeshFiles.read/write` | Shared types |
| U07, U08 → U05 | `ScanLibrary.add(mesh:method:detail:)`, raw-capture location | Shared interface, shared storage |
| U07, U08 → Capture screens | `CaptureCoordinator`, `CaptureEvent`, `CaptureMethod` | Shared state machine; defined in U07, extended by U08 and U09 |
| U07, U06, U13 | Camera and depth sensor | Shared resource: one holder at a time |
| U10 → U03 | Feature table JSON schema and reference mesh, bundled in the app | Shared data; schema fixed in U03 |
| U10 ↔ U05 | `attach(report:to:)`, "is reference" flag in the scan manifest | Shared storage |
| U11 → U10 | `AccuracyReport`, `AlignmentResult` | Shared types |
| U12 → U06, U05 | `SensorFrame`, scan source picture | Shared types |

The construction rule recorded in the phase guardrails applies at two of these: U10 with
U03 (a real scan of the real printed object, not only synthetic data) and U07/U08 with
U05 (a real capture saved and reopened), each tested end to end before its gate.
