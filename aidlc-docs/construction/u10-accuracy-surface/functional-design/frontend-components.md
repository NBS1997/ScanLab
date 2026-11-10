# Frontend Components — U10 Accuracy Stage 1

Inputs: `mockups.md` and `mockups.html` (screens 4 and 8, Reference object sheet), `interaction-spec.md` (Accuracy states, Verdict line), `design-system-mapping.md`, `accessibility-checklist.md` (A1–A6, A10–A12), `stories.md` (US-12, US-13).

## Scan detail additions — `ScanDetailView`, `ScanDetailModel`

| Part | Behaviour |
|---|---|
| ••• menu | Adds **Mark as reference object** or **Unmark as reference object** (uses `ScanLibrary.setReference`). |
| Details | Adds "Reference object: Yes/No" and, when a report exists, a green seal labelled "Has an accuracy report". |
| Check accuracy | Enabled only for a reference scan (AC-1); otherwise disabled, with the reason in the footer and the hint. Pushes the Accuracy screen. Coming back refreshes the details (the tick). |

## Accuracy (screen 8, stage 1) — `AccuracyView`, `AccuracyModel`

| Part | Behaviour |
|---|---|
| Header | Scan name and method. |
| Match (first) | Symbol and "Match good · 0.21 mm", then "Reference surface found 84%" and "Scan close to the shape 97%", then the verdict sentence. Unreliable: the verdict in red and each reason, and **no figures**. |
| Surface error by size | Whole surface, Small (up to 5 mm), Medium (5–30 mm), Large (over 30 mm), Rest of the surface: Mean (signed), RMS, 95% (±), Points. Footer explains the columns and that these are surface distances, not feature sizes. Only when reliable. |
| Your measurements | "No caliper values yet…" prompt, or "Caliper values: 12 entered"; **Reference object…** opens the sheet. |
| Details | Checked (date), scan points, background removed, alignment rounds. |
| Bottom bar | **Check again**, or **Cancel** while running. |
| States | Loading ("Opening the report…"); Running (progress bar with step name and percentage); Finished; Cancelled ("Nothing was saved"); Failed (reason in place, red, with text). |
| Deferred to U11 | Per-feature table, error by feature kind, Compare methods, Export (CSV). |

## Reference object sheet — `ReferenceObjectView`, `ReferenceObjectModel`

| Part | Behaviour |
|---|---|
| Layout | Sheet with Cancel and Save; intro text; "Entered N of 26"; sections in the measurement sheet's groups (Lengths between faces, Steps and heights, Holes, Round posts, Angles, Curved surfaces). |
| Row | ID (monospaced) and description; "Design 12 mm"; a decimal-pad box with the unit after it; a message; "How to measure" disclosure with the sheet's instruction. |
| Validation | Checked as typed (AC-2–AC-4): problems in red with an octagon symbol, warnings in orange with a triangle, always in words. Save is disabled while any box is unusable. |
| Save | Writes all usable values in one step; failure shown in place and logged. |

## Accessibility

- A1/A2: every control has a label; caliper boxes read "H3 caliper value in millimetres".
- A3: section headers; the scan name is marked as a header.
- A6: quality has a word as well as a colour; problems and warnings are text.
- A10: each size-class row is read as one element: label, then "mean +0.20 millimetres,
  RMS …, 95 percent within …, N points", naming every column.
- A4/A12: standard lists, so large text and sideways layouts reflow.
