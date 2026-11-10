# Refined Mockups — LidarApp MVP

Sources: `wireframes.md` and `user-flow.md` (rough mockups), `stories.md` (US-01 to
US-14), `requirements.md` (FR-1 to FR-10, NFR-6) and `team-practices.md`.
Answers: `refined-mockups-questions.md` (tones; verdict-first report; errors in place).

**Visual mockups:** open [mockups.html](mockups.html) in a browser. It draws all nine
screens upright, in the phone's light or dark setting. This document is the text
equivalent and the record of what each screen must contain.

## Screens

| # | Screen | Stories | Contains | Primary action |
|---|---|---|---|---|
| 1 | Library | US-10 | Title "Scans"; list rows (thumbnail, name, method · date · size, accuracy tick); links to Diagnostics and Explore | ＋ New scan |
| 2 | New scan | US-06, US-07 | Two method cards with a one-line "use this for"; surface tip | Pick a method |
| 3 | Capture | US-06–US-09 | Full-screen camera; captured areas tinted; timer or photo count; coverage bar; prompt only when needed; close | Finish |
| 4 | Scan detail | US-05, US-07, US-10 | Model view; Shape/Edges layer chips; method and detail level, size, faces, raw-capture status | Export |
| 5 | Export | US-11 | Detail level with face counts; file type; raw-capture switch; in-place error area | Choose where to save |
| 6 | Explore live | US-03, US-05 | Full-screen camera with layers; centre distance and frame rate; layer chips | Toggle layers |
| 7 | Hardware details | US-04 | Grouped values read from the phone; a finding row per group | Export findings |
| 8 | Accuracy report | US-13, US-14 | Match quality; one-sentence verdict; error by size and by feature kind; per-feature table | Compare methods |
| 9 | Diagnostics | US-01, US-02 | Version, build date, days to expiry; activity log with errors highlighted | Export log |

Two supporting sheets are not drawn separately: **Reference object** (a list of feature
IDs with design value and an editable caliper value, reached from Accuracy) and
**Compare methods** (two report summaries side by side).

## Changes from the Rough Mockups

- **Accuracy report leads with a plain verdict** (Q2-C), then error by size class, then
  the feature table. Match quality stays first of all.
- **Errors appear where they happened** (Q3-A), with reason and next step, and are logged.
- **Scan detail states the detail level used** (requirement FR-4.2), because the phone
  builds photo models at reduced detail only.
- **Export gains a raw-capture switch** (FR-7.5) and shows face counts per level (FR-7.3).
- **Explore shows the measured frame rate** beside the centre distance (NFR-7).
- **Diagnostics moved to the library's top bar**, replacing the "···" button.
- **Scan detail's bottom bar holds two actions only**: Check accuracy and Export. Rename
  and Delete moved to a "•••" menu in the top bar (tidy-up after owner review,
  2026-11-10), so no button label wraps and the destructive action is out of thumb reach.

## Text Fallback

Library: a titled list of scans with a New scan button and links to Accuracy, Explore
and Diagnostics. New scan: two choices, Sweep and Photos. Capture: a live camera picture
with tinted coverage, a coverage bar and a Finish button. Scan detail: a model with
details beneath, Check accuracy and Export, and a menu holding Rename and Delete. Export: detail level, file type,
raw-capture switch and a save button. Explore: a live picture with four layer toggles.
Hardware details: grouped readings with notes. Accuracy report: match quality, verdict,
summary tables. Diagnostics: build information and an activity log.
