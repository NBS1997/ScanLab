# User Flow — LidarApp MVP

Sources: [intent-statement.md](../intent-capture/intent-statement.md),
[scope-document.md](../scope-definition/scope-document.md) (capabilities 1–13),
[intent-backlog.md](../scope-definition/intent-backlog.md) (B1–B12) and
[rough-mockups-questions.md](rough-mockups-questions.md) (Q1–Q6).

## Information Architecture

The app opens on the scan library (Q1-B). Everything else is reached from there.

```
Library (home)
├── New scan
│   ├── Sweep capture ........... medium and large subjects
│   └── Photo capture ........... small parts
│       └── (either) → Processing → Scan detail
├── Scan detail
│   ├── View the model (edges layer on/off)
│   ├── Export (detail level → save to files / cloud)
│   ├── Check accuracy (reference-object scans only) → Accuracy report
│   └── Rename / delete
├── Explore
│   ├── Live view with layers (camera, depth, confidence, edges)
│   └── Hardware details (what the phone reports, and findings noted)
├── Accuracy
│   ├── Reference object (measured dimensions entered once)
│   └── Reports (one per reference scan, by capture method)
└── Diagnostics
    └── Activity log, app and build information, export log
```

Text fallback: Library is the root. It leads to New scan (two capture methods, both
ending at Scan detail), Scan detail (view, export, check accuracy, rename/delete),
Explore (live layers and hardware details), Accuracy (reference object and reports) and
Diagnostics.

## Core Flow: Scan a Part and Use It

The happy path that replaces the third-party app (metric S4).

```
[Library] → tap New scan → choose method
     → [Capture] move around the object
           haptics + sound warn: too fast / tracking lost
           screen shows what has been covered
     → tap Finish → [Processing] → [Scan detail]
     → tap Export → pick detail level → save to cloud folder
     → open the file on the computer in Fusion
```

Text fallback: from the library the owner starts a scan, picks sweep or photo capture,
moves around the object guided by haptics and sound with coverage visible on screen,
finishes, waits for processing, then exports at a chosen detail level to a cloud folder
and opens the file on the computer.

| Step | Screen | What the owner does | What the app does |
|---|---|---|---|
| 1 | Library | Taps **New scan** | Offers the two capture methods with a one-line hint on which suits what |
| 2 | Capture | Moves around the object | Alerts by haptics and sound (Q3); shows coverage on screen for a glance |
| 3 | Capture | Taps **Finish** | Builds the model; shows progress |
| 4 | Scan detail | Looks at the result | Shows the model; saves it to the library automatically |
| 5 | Scan detail | Taps **Export**, picks a detail level | Writes the file to the chosen location |
| 6 | Computer | Opens the file in Fusion, Blender or a slicer | — |

## Accuracy Flow: Find Out What to Trust

The risk-first path (metrics S1, S2; backlog B3, B5, B6).

```
(once) print reference object → measure with calipers → [Accuracy › Reference object] enter measurements
[Library] → New scan → scan the reference object (each method)
     → [Scan detail] → tap Check accuracy
     → [Accuracy report] error by feature and size, and how well the scan matched
```

Text fallback: the owner prints and measures the reference object once and enters its
measurements. They then scan it with each capture method and, from the scan's detail
screen, ask for an accuracy check, which produces a report of error by feature and size
together with how well the scan was matched to the reference.

## Exploration Flow: See the Hardware

Metric S3; backlog B2, B10, B11.

```
[Library] → Explore → [Live view] toggle layers: camera / depth / confidence / edges
                    → Hardware details → read what the phone reports → note a finding
```

Text fallback: from the library the owner opens Explore, switches layers on and off over
the live picture, and opens a details screen that lists what the hardware reports and
lets them note findings.

## Flow Decisions

- **Library first** (Q1-B) puts previous scans, not the camera, in front of the owner.
  Starting a scan is one tap from there.
- **Explore offers both** layers and a details screen (Q2-C).
- **Guidance is felt and heard** (Q3-B, C); the screen still shows coverage (follow-up).
- **Both orientations** work everywhere (Q4-C); capture screens keep controls reachable
  by the thumb in either.
- **Standard iPhone look** following the phone's light or dark setting (Q5-A).
