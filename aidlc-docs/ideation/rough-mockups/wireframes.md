# Wireframes — LidarApp MVP (low fidelity)

Sources: [user-flow.md](user-flow.md), [scope-document.md](../scope-definition/scope-document.md),
[intent-backlog.md](../scope-definition/intent-backlog.md) and
[intent-statement.md](../intent-capture/intent-statement.md).

Rough layouts only: what is on each screen and roughly where. Shown in portrait; every
screen also works in landscape (Q4-C). Standard iPhone look (Q5-A). Each screen carries a
one-line accessibility note. A phone has no keyboard, so "entry point" means where the
screen reader's focus lands first.

## 1. Library (home)

```
+----------------------------------+
| Scans                    [Explore]|
|----------------------------------|
| [thumb] Mirage Drive mount       |
|         Photo · 10 Nov · 4.2 MB  |
|----------------------------------|
| [thumb] Reference object #2      |
|         Sweep · 9 Nov · checked ✓|
|----------------------------------|
| [thumb] Hull section             |
|         Sweep · 8 Nov            |
|                                  |
|        (empty: "No scans yet")   |
|----------------------------------|
| [Accuracy]  [ + New scan ]  [···]|
+----------------------------------+
```

- Each row: thumbnail, name, method, date, size; a tick if an accuracy report exists.
- `[···]` opens Diagnostics.
- Accessibility: h1 "Scans"; regions header / main (list) / footer (actions); focus lands on the title, then the first scan.

## 2. New Scan — choose a method

```
+----------------------------------+
| < Back        New scan           |
|----------------------------------|
| +------------------------------+ |
| | Sweep                        | |
| | Larger things: 15 cm and up  | |
| | Move the phone over surfaces | |
| +------------------------------+ |
| +------------------------------+ |
| | Photos                       | |
| | Small parts: finer detail    | |
| | Circle the object            | |
| +------------------------------+ |
+----------------------------------+
```

- Accessibility: h1 "New scan"; main region with two buttons; focus lands on "Sweep".

## 3. Capture (both methods)

```
+----------------------------------+
| [X]                    00:42     |
|                                  |
|        live camera picture       |
|     with captured areas tinted   |
|                                  |
|   "Tracking lost — move back"    |  <- prompt appears only when needed
|                                  |
| Coverage ███████░░░  68%         |
|            ( Finish )            |
+----------------------------------+
```

- Alerts come as haptics and sound (Q3); the tint and coverage bar are for a glance.
- Photo method shows a count of photographs taken in place of the timer.
- Accessibility: no heading (full-screen camera); main region; focus lands on "Finish"; alerts are also announced by the screen reader.

## 4. Scan Detail

```
+----------------------------------+
| < Scans   Mirage Drive mount  [✎]|
|----------------------------------|
|                                  |
|      3D model — drag to turn     |
|                                  |
|  Layers: [Shape] [Edges]         |
|----------------------------------|
| Photos · 10 Nov · 182,000 faces  |
|----------------------------------|
| [ Export ]   [ Check accuracy ]  |
| [ Delete ]                       |
+----------------------------------+
```

- `Check accuracy` appears only for scans marked as the reference object.
- Accessibility: h1 scan name; regions header / main (model, details) / footer (actions); focus lands on the name; the model has a text description of its size.

## 5. Export

```
+----------------------------------+
| Cancel         Export            |
|----------------------------------|
| Detail                           |
|  ( ) Full        182,000 faces   |
|  (•) Fusion-friendly  ~20,000    |
|  ( ) Light       ~5,000          |
|----------------------------------|
| File type      [ common 3D file ]|
| Save to        [ Cloud folder  ] |
|----------------------------------|
|            ( Export )            |
+----------------------------------+
```

- Accessibility: h1 "Export"; main region is a form; focus lands on the first detail option.

## 6. Explore — live view with layers

```
+----------------------------------+
| < Scans      Explore     [Details]|
|                                  |
|       live picture with the      |
|       selected layers over it    |
|                                  |
|  Centre distance: 0.43 m         |
|----------------------------------|
| [Camera][Depth][Confidence][Edges]|
+----------------------------------+
```

- Layers toggle independently (Q2-C).
- Accessibility: h1 "Explore"; regions header / main / footer (layer toggles); focus lands on the first toggle; the distance reading is announced on request.

## 7. Explore — hardware details

```
+----------------------------------+
| < Explore   Hardware details     |
|----------------------------------|
| Depth sensor                     |
|   Reported range ........ —      |
|   Reported grid ......... —      |
|   Finding: [ add a note ]        |
|----------------------------------|
| Cameras                          |
|   Wide / Ultra-wide / Telephoto  |
|   Offsets and lens data ..... >  |
|   Finding: [ add a note ]        |
|----------------------------------|
| [ Export findings ]              |
+----------------------------------+
```

- Values are whatever the phone reports; dashes until first run. Findings feed metric S3.
- Accessibility: h1 "Hardware details"; h2 per sensor group; main region; focus lands on the title.

## 8. Accuracy — reference object and report

```
+----------------------------------+
| < Scans       Accuracy           |
|----------------------------------|
| Reference object                 |
|   Measured dimensions  [ Edit ]  |
|----------------------------------|
| Report: Reference #2 · Photos    |
|   Match quality ....... good     |
|   Feature        Known   Scan  Δ |
|   20 mm cube     20.1    20.6 +0.5|
|   5 mm step       5.0     5.9 +0.9|
|   Ø10 hole       10.0     9.1 -0.9|
|   ...                            |
|   Typical error by size:         |
|   <10 mm ±0.9 · 10–50 mm ±0.6    |
|----------------------------------|
| [ Compare methods ] [ Export ]   |
+----------------------------------+
```

- Numbers above are placeholders to show layout, not predictions.
- Match quality tells the owner whether the figures can be trusted (scope boundary decision).
- Accessibility: h1 "Accuracy"; h2 "Reference object", h2 report title; the table has row and column headers; focus lands on the title.

## 9. Diagnostics

```
+----------------------------------+
| < Scans      Diagnostics         |
|----------------------------------|
| App version · build · delivered  |
| Build expires in 61 days         |
|----------------------------------|
| Activity                         |
|  10:42 Capture started (Photos)  |
|  10:44 Tracking lost ×2          |
|  10:47 Model built · 182k faces  |
|  10:47 Export failed: no space   |
|----------------------------------|
| [ Export log ]                   |
+----------------------------------+
```

- Accessibility: h1 "Diagnostics"; h2 "Activity"; main region; focus lands on the title.

## Screen-to-Capability Map

| Screen | Scope capabilities | Backlog |
|---|---|---|
| 1 Library | 9 | B9 |
| 2 New scan | 3, 6 | B2, B5 |
| 3 Capture | 3, 6, 10 | B2, B5, B8 |
| 4 Scan detail | 9, 11 | B9, B10 |
| 5 Export | 4, 8 | B2, B7 |
| 6 Explore live | 2, 11 | B2, B10 |
| 7 Hardware details | 12 | B11 |
| 8 Accuracy | 5, 7 | B3, B6 |
| 9 Diagnostics | 13 | B4, B12 |
