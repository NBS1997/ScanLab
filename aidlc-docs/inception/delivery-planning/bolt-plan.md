# Bolt Plan — ScanLab (LidarApp)

Inputs: `unit-of-work.md`, `unit-of-work-dependency.md` (the dependency DAG),
`unit-of-work-story-map.md`, `requirements.md`, `stories.md`, `decisions.md`,
`.claude/rules/aidlc-team.md` and `delivery-planning-questions.md` (sequence as proposed;
no forced stop at the decision point; the agent creates the GitHub repository).

Practices applied from `aidlc-team.md`: trunk-based, one squash-merged commit per Bolt
named by its slug; walking skeleton first, solo and gated; tests on sensor-independent
logic with at least 80% coverage, on-device checklist for the rest; every merge to `main`
builds and delivers to TestFlight.

## Sequence

| Step | Bolt | Slug | Units | Runs |
|---|---|---|---|---|
| 1 | Bolt 1 — **walking skeleton** | `walking-skeleton` | U01, U02 | Solo, always gated |
| 2 | Bolt 2 | `reference-object` | U03 | Parallel batch |
| 2 | Bolt 3 | `geometry-export` | U04 | Parallel batch |
| 2 | Bolt 4 | `live-sensor-view` | U06 | Parallel batch |
| 3 | Bolt 5 | `scan-library` | U05 | Solo |
| 4 | Bolt 6 | `sweep-capture` | U07 | Parallel batch |
| 4 | Bolt 7 | `photo-capture` | U08 | Parallel batch |
| 4 | Bolt 8 | `accuracy-surface` | U10 | Parallel batch |
| 5 | Bolt 9 | `accuracy-features` | U11 | Parallel batch |
| 5 | Bolt 10 | `capture-guidance` | U09 | Parallel batch |
| 6 | Bolt 11 | `edge-detection` | U12 | Parallel batch |
| 6 | Bolt 12 | `hardware-details` | U13 | Parallel batch |

Every Bolt's position respects the DAG: each Unit's prerequisites are in an earlier step.

## Definition of Done (every Bolt)

- Core code for the Bolt has tests; the build's Core coverage stays at or above 80%.
- Formatting and lint pass; the build is green and the app is delivered to TestFlight.
- New behaviour writes diagnostics log entries (project rule).
- Non-obvious code is explained in plain language (project rule).
- An on-device checklist is supplied for any sensor-dependent or screen change, built
  from the story's acceptance criteria and the accessibility checklist.
- No secret, paid dependency or sign-up has been added.
- Squash-merged to `main` as one commit named by the slug.

## Bolts

### Bolt 1 — Walking skeleton (U01, U02) · `walking-skeleton`
- **Walking skeleton:** yes. Proves every layer end to end: the build workflow, signing
  and TestFlight delivery; the Core package and its tests with coverage in the build; an
  adapter (`FileLog`) behind a Core port; SwiftUI screens; and on-phone storage.
- **Before it can run:** the public GitHub repository is created by the agent with the
  owner's confirmation of the name; the owner adds the signing secrets (see
  `external-dependency-map.md`).
- **Bolt DoD (in addition):** the owner installs the build from TestFlight, sees the
  empty library, sees version, build date and expiry on Diagnostics, sees log entries
  for app launch, force-quits, and still sees them.
- **Confidence hypothesis:** "A change merged on Windows reaches the phone with no Mac,
  and the app can tell us what it did." Falsified if signing or upload cannot be made to
  work from the reused workflow (R8).
- **Expected demo:** open ScanLab from TestFlight; Diagnostics shows the build and a
  growing log; export the log to the Files app.
- **Stories:** US-01, US-02.

### Bolt 2 — Reference object (U03) · `reference-object`
- **Bolt DoD:** the script produces an STL that fits 340 × 320 × 340 mm, a STEP file that
  opens in Fusion, the feature table JSON, and the measurement sheet; the object has all
  five feature kinds at three or more sizes and no symmetry; generated files committed.
- **Confidence hypothesis:** "One script can be the single source of truth for print,
  design file and feature table." Also starts the print-and-measure lead time early.
- **Expected demo:** the owner opens the STL in the slicer and the STEP in Fusion.
- **Stories:** US-12 (design, print, measure).

### Bolt 3 — Geometry and export (U04) · `geometry-export`
- **Bolt DoD:** a built-in sample mesh exports as STL and OBJ at Full, Fusion-friendly
  (≤ 10,000 faces) and Light (≤ 5,000 faces) through the save chooser; tests prove face
  limits and millimetre scale.
- **Confidence hypothesis:** "Our own simplifier and writers produce files that Fusion
  converts to a solid at true size." Retires R5 before any real scan exists.
- **Expected demo:** export the sample to a cloud folder, insert it in Fusion, convert to
  a solid, check dimensions.
- **Stories:** US-11 (scan export path).

### Bolt 4 — Live sensor view (U06) · `live-sensor-view`
- **Bolt DoD:** Explore shows camera, depth and confidence layers in any combination,
  centre distance and frame rate; works upright and sideways; on-device checklist passed.
- **Confidence hypothesis:** "The depth sensor's live output can be shown and measured
  in our own app." First direct observation of the hardware (S3).
- **Expected demo:** point at a wall measured at 1.00 m and record the reading as a
  finding.
- **Stories:** US-03.

### Bolt 5 — Scan library (U05) · `scan-library`
- **Bolt DoD:** scans (seeded from the sample mesh) are listed with all six details,
  open in Scan detail, rename, delete with confirmation, and survive installing a newer
  build.
- **Confidence hypothesis:** "Scan data survives crashes and updates." Retires the
  storage half of NFR-8 before real captures depend on it.
- **Expected demo:** install the next build and see the same scans.
- **Stories:** US-10.

### Bolt 6 — Sweep capture (U07) · `sweep-capture`
- **Bolt DoD:** New scan → Sweep → Finish saves a scan of a subject 0.5 m or larger;
  real end-to-end check: capture, save, reopen, export to Fusion (construction rule).
- **Confidence hypothesis:** "The platform's scene reconstruction gives usable overall
  shape at true size for medium and large subjects."
- **Expected demo:** sweep a section of the kayak hull and open it in Fusion. With
  Bolts 3–5 this completes the **thin first version** the owner asked for (one live view,
  one scan-to-file path).
- **Stories:** US-06.

### Bolt 7 — Photo capture (U08) · `photo-capture`
- **Bolt DoD:** a photo capture of an object under 150 mm builds a model offline with
  progress, shows the detail level, offers to keep the raw capture, and exports it;
  real end-to-end check from capture to Fusion.
- **Confidence hypothesis:** "On-device photogrammetry at reduced detail gives a usable
  small-part model with true scale." The central risk R1; may be falsified.
- **Expected demo:** photo-scan a small fitting and open it in Fusion; observe and log
  whether building continues when the app is in the background.
- **Stories:** US-07, US-11 (raw export).

### Bolt 8 — Accuracy stage 1 (U10) · `accuracy-surface`
- **Bolt DoD:** synthetic scans with known error are reported correctly within 0.05 mm
  in the build; on the phone, caliper values can be entered, a reference scan gives
  match quality, verdict and surface error by size class, and a scan of another object
  is reported unreliable; real end-to-end check with the printed object (construction
  rule).
- **Confidence hypothesis:** "Automatic alignment is accurate enough that its own error
  is small compared with scan error." Assumption RA3.
- **Expected demo:** the first real accuracy numbers.
- **Stories:** US-12 (entering values), US-13 (stage 1).

### Decision point (after step 4)
Once Bolts 6–8 are merged, the Bolt summary reports the first accuracy figures for both
capture methods and recommends whether to continue as planned, bring multi-camera
correction (B14) forward, or redirect. **This is not a forced stop** (owner's choice,
Q2-B): it follows the gate mode chosen after the walking skeleton.

### Bolt 9 — Accuracy stage 2 (U11) · `accuracy-features`
- **Bolt DoD:** per-feature caliper-versus-scan table, error by feature kind,
  side-by-side comparison of two methods, CSV export; fitting proven on synthetic data
  in the build.
- **Confidence hypothesis:** "Feature dimensions can be fitted reliably from real scans."
- **Expected demo:** compare a sweep report and a photo report of the reference object;
  open the CSV in a spreadsheet.
- **Stories:** US-13 (stage 2), US-14.

### Bolt 10 — Capture guidance and interruption (U09) · `capture-guidance`
- **Bolt DoD:** haptic, tone and spoken alerts within one second; coverage on screen;
  interrupted captures kept with Continue and Build; previously saved scans intact.
- **Confidence hypothesis:** "Guidance through touch and sound lets the owner capture
  without watching the screen."
- **Expected demo:** cover the camera mid-capture; take a phone call mid-capture.
- **Stories:** US-08, US-09.

### Bolt 11 — Edge detection (U12) · `edge-detection`
- **Bolt DoD:** edges layer live in Explore and over a scan's source picture; a finding
  recorded on whether a sharp step is picked out.
- **Confidence hypothesis:** "Camera edges reveal detail the depth sensor misses."
- **Stories:** US-05.

### Bolt 12 — Hardware details and findings (U13) · `hardware-details`
- **Bolt DoD:** every listed value read from the phone at runtime; findings persist and
  export; depth still captured and shown.
- **Confidence hypothesis:** "We can document every sensing capability first-hand" —
  completes metric S3.
- **Stories:** US-04.

## Construction Stages Per Bolt

In `mvp` scope each Bolt runs Functional Design, NFR Requirements, NFR Design,
Infrastructure Design (where relevant) and Code Generation; Build and Test and the CI
Pipeline stage run once after all Bolts. Infrastructure Design for this project means
the build workflow only (no cloud), and is expected to matter only for Bolt 1.
