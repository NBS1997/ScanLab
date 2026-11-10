# Interaction Specification — LidarApp MVP

Sources: `mockups.md`, `user-flow.md`, `wireframes.md`, `stories.md`, `requirements.md`,
`team-practices.md`.

## Navigation

- One navigation stack rooted at Library. New scan, Scan detail, Explore, Accuracy and
  Diagnostics are pushed from it; Export and Reference object are sheets.
- Capture is full-screen and modal: it is left only by Finish or Close.
- Close during capture asks: Keep and build / Keep for later / Discard (FR-5.4).

## Screen States

| Screen | Empty | Loading | Error | Partial |
|---|---|---|---|---|
| Library | "No scans yet" with New scan | — | Storage unreadable: message in place | Scan still building: row shows progress |
| Capture | — | "Starting camera" | Camera permission refused: explains how to allow it; sensor unavailable: message | Tracking lost: prompt, haptic, tone; capture continues |
| Scan detail | — | Model building: progress bar, updated at least every 10 s (FR-4.3) | Build failed: reason, Retry from raw capture if kept | Built from an interrupted capture: labelled "partial" |
| Export | — | Writing file | Failed: reason and next step in place (Q3-A) | — |
| Explore live | — | "Starting camera" | Permission refused, or layer unsupported on this phone: layer chip disabled with reason | — |
| Hardware details | Dashes before first read | Reading | A value the phone does not report: "not reported" | — |
| Accuracy report | No reference measurements: prompt to enter them | Matching | Match unreliable: states so, no figures (FR-9.4) | Some features unmeasured: listed as "no caliper value" |
| Diagnostics | "No activity yet" | — | — | — |

## Capture Guidance (Q1-A: tones)

| Event | Haptic | Tone | On screen | Screen reader |
|---|---|---|---|---|
| Moving too fast | Two light taps | Short rising | "Slow down" | Spoken |
| Tracking lost | One heavy buzz | Low double | "Tracking lost — move back" | Spoken |
| Tracking recovered | One light tap | Short neutral | Prompt clears | Spoken |
| Coverage sufficient | Success pattern | Short chime | Coverage bar full | Spoken |

Tones follow the phone's silent switch; haptics still fire when silent.

## Components

| Component | Purpose | Behaviour | States |
|---|---|---|---|
| Scan row | One scan in the library | Tap opens detail; swipe reveals Delete; long-press offers Rename | Normal, building, has report |
| Method card | Choose capture method | Tap starts capture | Normal, unavailable (with reason) |
| Coverage bar | Shows capture progress | Grows with coverage; never decreases | 0–100% |
| Prompt | Transient guidance | Appears on event, clears on recovery | Hidden, shown |
| Layer chip | Toggle a layer | Independent on/off; state kept while the screen is open | On, off, disabled |
| Model view | Show a 3D model | Drag turns, pinch zooms, double-tap resets | Loading, shown, failed |
| Detail picker | Choose export detail | Single choice; face count per option | Selected, unselected |
| In-place error | Report a failure | Stays until the action is retried or the screen is left; names reason and next step; logged | Shown, hidden |
| Verdict line | One-sentence accuracy summary | Generated from the size-class figures | Good, limited, unreliable |
| Finding note | Owner's observation | Tap to edit; saved on leaving the field | Empty, filled |

## Orientation

- Capture and Explore: picture stays full-screen; controls move to the trailing edge
  when sideways; rotating never stops a capture (FR-3.3).
- List and form screens: same structure, wider rows.
- Accuracy report: sideways shows the feature table and summary side by side.

## Destructive Actions

Delete scan and Discard capture require confirmation naming what is lost and how much
storage is freed. Nothing else is destructive.
