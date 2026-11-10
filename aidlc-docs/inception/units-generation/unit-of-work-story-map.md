# Unit-to-Story Map — ScanLab (LidarApp)

Inputs: `unit-of-work.md`, `unit-of-work-dependency.md`, `stories.md` (US-01 to US-14),
`requirements.md`, and the Application Design artefacts (`components.md`,
`component-methods.md`, `services.md`, `component-dependency.md`, `decisions.md`).

## Story to Units

| Story | Implementing Units | Primary |
|---|---|---|
| US-01 Get the app onto my phone | U01 | U01 |
| US-02 See what the app has been doing | U02, plus every later Unit (logging) | U02 |
| US-03 Watch the sensor live | U06 | U06 |
| US-04 See what my phone reports and note what I find | U13 | U13 |
| US-05 See edges picked out | U12 | U12 |
| US-06 Sweep-scan something larger | U07, U05 | U07 |
| US-07 Photo-scan a small part | U08, U05 | U08 |
| US-08 Be guided while I capture | U09 | U09 |
| US-09 Not lose a capture when interrupted | U09 | U09 |
| US-10 Keep and manage my scans | U05 | U05 |
| US-11 Get a scan into my design tools | U04 (scans), U08 (raw capture) | U04 |
| US-12 Print and measure a reference object | U03 (design, print), U10 (enter values) | U03 |
| US-13 Get an accuracy report I can believe | U10 (match, verdict, deviation), U11 (per-feature) | U10 |
| US-14 Compare methods and keep the numbers | U11 | U11 |

## Cross-Cutting Concerns

| Concern | Stories | Units | Handled by |
|---|---|---|---|
| Diagnostics entries for new behaviour | US-02 last criterion; project rule | All from U02 on | Each Unit's Definition of Done includes its log events |
| Upright and sideways | US-03, US-06 and all screens (NFR-6) | Every Unit with a screen | Accessibility checklist A12 at each gate |
| Screen-reader labels and text size | All (NFR-6) | Every Unit with a screen | Accessibility checklist at each gate |
| Storage checks and clean failures | US-07, US-10, US-11 (NFR-9) | U04, U05, U08 | `StoreError.noSpace` path in each |
| Sensor ownership | US-03, US-04, US-06, US-07 | U06, U07, U08, U13 | One holder at a time (`component-dependency.md`) |

## Order Within Each Unit

Each Unit builds its acceptance criteria in this order: Core types and tests first, then
the adapter, then the screen, then the on-device checklist.

| Unit | Story criteria, in build order |
|---|---|
| U01 | US-01: delivered build → opens on library → build info shown → monthly schedule |
| U02 | US-02: entries recorded → survive relaunch → export |
| U03 | US-12: fits printer → features and asymmetry → measurement sheet |
| U04 | US-11: STL/OBJ at true size → detail levels and face counts → save chooser → offline export |
| U05 | US-10: list and details → rename → delete → survive update |
| U06 | US-03: layers → centre distance → frame rate → rotation |
| U07 | US-06: capture and finish → model view → rotation mid-capture → auto-save |
| U08 | US-07: offline capture and build → progress and resume → detail level → keep or discard raw; US-11: raw export |
| U09 | US-08: haptic and tone → coverage → spoken; US-09: keep on interrupt → build partial → library intact |
| U10 | US-12: enter caliper values; US-13: one-tap report → match quality first → unreliable path → error by size class → synthetic test |
| U11 | US-13: per-feature table → error by feature kind → synthetic fitting test; US-14: comparison → CSV |
| U12 | US-05: live edges → edges on scan → finding |
| U13 | US-04: reported values → findings persist → findings export → depth still |

## Coverage Check

- **Every story is assigned:** 14 of 14 stories map to at least one Unit.
- **Every Unit has stories:** U01–U13 each implement at least one story's criteria.
- **Every functional requirement area is covered** through the stories (see the coverage
  table in `stories.md`).
