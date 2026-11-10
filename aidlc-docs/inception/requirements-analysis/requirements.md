# Requirements — LidarApp MVP

Sources (Ideation): intent-statement (metrics S1–S4), feasibility-assessment,
constraint-register (TC, OC, RC), raid-log (R, A), scope-document (capabilities 1–13),
intent-backlog (B1–B16), wireframes and user-flow.
Sources (this stage): [requirements-analysis-questions.md](requirements-analysis-questions.md)
(Q1–Q8) and [platform-verification.md](platform-verification.md) (V1–V12).

Each requirement has a pass/fail check and a trace to its origin. Priority follows the
backlog: **M** must, **S** should, **C** could.

## Intent Analysis

- **Request type:** new product. **Scope:** whole system (app, build pipeline, a physical
  reference object). **Complexity:** complex — hardware behaviour is partly unverified
  and there is no local build environment. **Depth:** Standard.
- **What the owner is trying to achieve:** two things of equal weight. First, to turn a
  real part into a 3D model whose dimensions they can trust and design around, with no
  third-party app or sign-up in the way. Second, to understand first-hand what the
  phone's LiDAR and cameras can and cannot do.
- **What "done" means:** the owner knows, with numbers from a reference object, how
  accurate each capture method is (S1, S2); has exercised each sensing capability and
  written down its limits (S3); and no longer needs the third-party app (S4).
- **What it does not mean:** a polished product for other people, or a guarantee of
  millimetre accuracy. If the hardware cannot deliver the accuracy hoped for, a clear
  measurement saying so is a successful outcome of S1.

## Functional Requirements

### FR-1 Delivery and app shell

| ID | Requirement | Pass/fail check | Pri | Trace |
|---|---|---|---|---|
| FR-1.1 | The app is built on the hosted build service and delivered to the owner's phone through TestFlight with no Mac involved. | A merge to `main` results in a new build installable from TestFlight on the phone. | M | Cap 1, B1, TC1 |
| FR-1.2 | The app opens on the scan library. | Cold launch shows the library screen. | M | Mockups Q1-B |
| FR-1.3 | The app shows its version, build number, build date and days until the build expires. | Values on the Diagnostics screen match the TestFlight build; expiry equals build date plus 90 days. | M | Cap 13, V8 |
| FR-1.4 | A rebuild and redelivery runs on a schedule so an installed build never expires. | With no code change for 60 days, a new build still arrives before day 90. | S | B12, R9 |

### FR-2 Hardware exploration

| ID | Requirement | Pass/fail check | Pri | Trace |
|---|---|---|---|---|
| FR-2.1 | A live view shows the camera picture with depth, confidence and edge layers that can each be switched on and off independently. | Each of the four layers can be toggled alone and in any combination while the view stays live. | M | Cap 2, 11; Mockups Q2-C |
| FR-2.2 | The live view shows the measured distance at the centre of the picture. | Pointing at a wall 1.00 m away (tape-measured) shows a reading; the reading and its error are recorded as an S3 finding. | M | Cap 2 |
| FR-2.3 | A hardware details screen lists what this phone reports: depth formats and sizes, each rear camera with focal length, lens and offset data, the camera combinations that can run together, and the file types the phone can export. | Every listed value is read from the phone at runtime; none is hard-coded. | M | Cap 12, V1, V6, V10 |
| FR-2.4 | The owner can attach a written finding to each capability, and findings persist. | A finding entered, then the app closed and reopened, is still shown. | M | Cap 12, S3 |
| FR-2.5 | Hardware details and findings can be exported as one text file. | The exported file contains every listed value and every finding. | M | S3 |
| FR-2.6 | The higher-resolution depth still (outside the live tracking path) can be captured and viewed. | A depth still can be taken and displayed, with its reported size shown. | S | V1, S3 |

### FR-3 Sweep capture (depth sensor)

| ID | Requirement | Pass/fail check | Pri | Trace |
|---|---|---|---|---|
| FR-3.1 | The owner can start a sweep capture, move the phone over a subject and finish it, producing a 3D surface model. | A sweep of a subject of at least 0.5 m yields a model viewable in the app. | M | Cap 3, B2 |
| FR-3.2 | A finished scan is saved to the library automatically. | After finishing, the scan appears in the library without a save step. | M | Cap 9 |
| FR-3.3 | Capture works with the phone upright or sideways. | A capture can be started, rotated mid-capture and finished without failing. | M | Mockups Q4-C |

### FR-4 Photo capture (photographs plus depth)

| ID | Requirement | Pass/fail check | Pri | Trace |
|---|---|---|---|---|
| FR-4.1 | The owner can capture a small object by taking many photographs around it, and the app builds a 3D model on the phone. | A photo capture of an object under 150 mm yields a model viewable in the app, with no network connection. | M | Cap 6, B5, V4 |
| FR-4.2 | The model is built at the highest detail level the phone supports, and the app states which level was used. | Scan detail shows the detail level reported by the platform. | M | V4 |
| FR-4.3 | While a model is being built, progress is shown, and leaving the app does not lose the capture. | Progress updates at least every 10 s; after switching away and back, the build completes or resumes without recapturing. | M | Q4-C |
| FR-4.4 | The model carries real-world size. | The model's overall dimensions are reported in millimetres; agreement with reality is measured by FR-9, not assumed. | M | S2, V4 |

### FR-5 Capture guidance and interruption

| ID | Requirement | Pass/fail check | Pri | Trace |
|---|---|---|---|---|
| FR-5.1 | Moving too fast or losing tracking triggers a haptic alert and a sound. | Deliberately covering the camera during capture produces both within 1 s. | M | Cap 10, Mockups Q3 |
| FR-5.2 | The live picture shows which areas have been captured, and an overall coverage indication. | Captured areas are visibly marked; the indication increases as more is captured. | M | Cap 10, Mockups Q3 follow-up |
| FR-5.3 | Alerts are also announced by the screen reader when it is on. | With the screen reader on, a tracking-lost alert is spoken. | M | NFR-6 |
| FR-5.4 | If a capture is interrupted, what was captured is kept, and on return the owner can continue or build from it. | Switching apps mid-capture and returning offers both choices; choosing "build" yields a model. | M | Q7-A |

### FR-6 Scan library and scan detail

| ID | Requirement | Pass/fail check | Pri | Trace |
|---|---|---|---|---|
| FR-6.1 | The library lists every scan with thumbnail, name, capture method, date, size on the phone, and a mark if an accuracy report exists. | All six items are shown for each scan. | M | Cap 9 |
| FR-6.2 | Scans can be renamed and deleted; deletion asks for confirmation. | Rename persists across relaunch; delete removes the scan and frees its storage after confirmation. | M | Cap 9 |
| FR-6.3 | Scans survive app relaunch and app updates. | Scans present before installing a new TestFlight build are present after. | M | Cap 9 |
| FR-6.4 | Scan detail shows the model, which can be turned and zoomed, with its face count and overall dimensions. | Dimensions are shown in millimetres, or metres when any dimension is 1 m or more. | M | Cap 9, Q6-B |
| FR-6.5 | Detected edges can be shown over the model or its source picture. | An edges layer can be toggled on scan detail. | M | Cap 11, B10 |
| FR-6.6 | After a photo capture, the app asks whether to keep the raw capture, and shows how much storage it uses. | The prompt appears once per capture; choosing "discard" frees the storage. | M | Q5-C |

### FR-7 Export

| ID | Requirement | Pass/fail check | Pri | Trace |
|---|---|---|---|---|
| FR-7.1 | A scan can be exported as STL and as OBJ. | Both files open in Fusion (Insert Mesh), Blender and a slicer. | M | Cap 4, TC5, V10, V11 |
| FR-7.2 | Exported files carry true size in millimetres. | Overall dimensions measured in Fusion match those shown in the app to within 0.1%. | M | S2, TC5 |
| FR-7.3 | Three detail levels are offered: Full; Fusion-friendly (at most 10,000 faces); Light (at most 5,000 faces). The face count of each is shown before export. | The exported Fusion-friendly file has 10,000 faces or fewer and converts to a solid in Fusion. | M | Cap 8, B7, V11 |
| FR-7.4 | Every export asks where to save, using the phone's standard chooser. | The chooser appears on every export and can save to a cloud folder visible from the Windows computer. | M | Q1-A, TC7 |
| FR-7.5 | The raw capture (photographs, camera positions and depth data) can be exported to a chosen folder. | The exported folder contains every photograph and a file of camera positions. | M | Q8-A (new, see Origin Notes) |
| FR-7.6 | 3MF export. | A 3MF file opens in Fusion and a slicer. | C | V11 |

### FR-8 Reference object

| ID | Requirement | Pass/fail check | Pri | Trace |
|---|---|---|---|---|
| FR-8.1 | A reference object is designed for the owner to print, fitting within 340 × 320 × 340 mm. | The design's overall dimensions are within that volume. | M | Cap 5, B3, Q2 |
| FR-8.2 | It includes all five feature kinds — lengths between faces, steps, holes and round bosses, angles, curved surfaces — each at several sizes spanning small-part to medium scale. | Each feature kind appears at no fewer than three sizes, the smallest 2 mm or under and the largest 100 mm or over where the kind allows. | M | Q3, S1 |
| FR-8.3 | Its shape is unambiguous: it cannot be matched to a scan in more than one orientation. | The design has no rotational or mirror symmetry. | M | Scope boundary decision |
| FR-8.4 | Every measurable feature has an identifier and a design dimension, listed in a measurement sheet the owner fills in with calipers. | The sheet lists each feature ID, what to measure, and the design value. | M | A8, S1 |
| FR-8.5 | The design is supplied as a printable file and an editable design file. | Both files are in the repository and the printable file loads in a slicer. | M | Feasibility Q6 |
| FR-8.6 | The app stores the reference object's definition and the owner's measured values per feature. | Measured values entered are kept across relaunch and can be edited. | M | Cap 7 |

### FR-9 Accuracy report

| ID | Requirement | Pass/fail check | Pri | Trace |
|---|---|---|---|---|
| FR-9.1 | A scan can be marked as a scan of the reference object. | Marking it enables "Check accuracy" on that scan only. | M | Cap 7 |
| FR-9.2 | The app matches the scan to the reference object's known shape automatically, with no manual measuring. | A report is produced from one tap, with no points picked by the owner. | M | Scope Q7-C |
| FR-9.3 | The report states how well the scan matched, as a number and a plain rating. | Match quality is shown before any feature figures. | M | Scope boundary decision |
| FR-9.4 | When the match is poor, the report says its figures are unreliable and does not present them as accuracy. | A deliberately wrong scan (a different object) produces an "unreliable" result, not error figures. | M | Scope boundary decision |
| FR-9.5 | The report lists, per feature: measured (caliper) value, scanned value and the difference. | Each feature ID from FR-8.4 with a measured value appears as a row. | M | S1 |
| FR-9.6 | The report summarises typical error by feature kind and by size class. | The summary has one line per feature kind and per size class present. | M | S1, Q3 |
| FR-9.7 | Reports for the same reference object from different capture methods can be shown side by side. | Two reports can be compared on one screen. | M | B6, A2 |
| FR-9.8 | A report can be exported as a file readable in a spreadsheet. | The exported file opens in a spreadsheet with one row per feature. | M | S1 |
| FR-9.9 | The accuracy calculation gives the right answer on known inputs. | Given a synthetic scan with a known built-in error, the reported error matches it to within 0.05 mm. | M | Testing posture |

### FR-10 Diagnostics

| ID | Requirement | Pass/fail check | Pri | Trace |
|---|---|---|---|---|
| FR-10.1 | The app keeps a timestamped activity log: capture start and finish, tracking loss, model building, export, and every error with its reason. | Each of those events appears in the log after it happens. | M | Cap 13, B4, R2 |
| FR-10.2 | The log survives relaunch and crashes, keeping at least the most recent 1,000 entries. | Entries written before a forced quit are present after relaunch. | M | Cap 13 |
| FR-10.3 | The log can be exported as a text file. | The exported file contains the entries shown on screen. | M | Cap 13 |
| FR-10.4 | Every capability added later writes to the log. | Reviewed at each Bolt: new behaviour has log entries. | M | Rule: diagnosable on the phone |

## Non-Functional Requirements

| ID | Requirement | Target / check | Trace |
|---|---|---|---|
| NFR-1 Platform | Runs on the owner's iPhone 17 Pro Max on its current system version. No other device is supported. | Installs and launches on that phone. Minimum system version is set in Application Design once the phone's version is confirmed (Open Question 1). | TC2, V7 |
| NFR-2 Offline | Every capability works with no network connection. | All FR checks pass in aeroplane mode, except delivery (FR-1.1) and saving to a cloud folder. | TC6, RC5 |
| NFR-3 Privacy | No scan data, photographs or logs leave the phone except by an export the owner starts. The app makes no network requests. | A review of the code finds no network calls; no analytics or crash-reporting service is included. | RC5 |
| NFR-4 Security | No signing key, certificate or credential is in the repository. Protected capabilities (camera) carry the required purpose statement. | A secret scan of the repository is clean; the app launches without a permissions failure. | RC1, RC2 |
| NFR-5 Cost | No paid dependency, service or account beyond what the owner already has. | Every dependency is free and its licence is recorded before it is added. | OC2, RC4 |
| NFR-6 Accessibility | Respects the phone's text size, contrast, light/dark and screen-reader settings; works upright and sideways. | Every control has a screen-reader label; no text is cut off at the largest standard text size. | Mockups Q4–Q6 |
| NFR-7 Responsiveness | The live view stays smooth with all layers on. | At least 30 pictures per second, measured by the app and written to the log. *Target to be validated on the phone.* | Cap 2 |
| NFR-8 Reliability | A saved scan is never lost or corrupted by a crash, an interruption or an update. | Forced quit during any operation leaves previously saved scans intact. | FR-6.3 |
| NFR-9 Storage | The owner can see how much space each scan and its raw capture use. An export or capture that would run out of space fails with a clear message and no partial file. | Storage shown per scan; filling the phone produces a logged, readable error. | Q5-C |
| NFR-10 Testability | Sensor-independent logic has automated tests with at least 80% line coverage, run in every build. Sensor-dependent behaviour has an on-device checklist per delivery. | Coverage is measured and reported by the build; each delivery that changes sensor behaviour includes a checklist. | Team practices |
| NFR-11 Maintainability | Formatter and linter run in every build and block on failure. Non-obvious code is explained in plain language. | Build fails on a formatting or lint error. | Team practices, OC1 |
| NFR-12 Build loop | The time from merge to an installable build is measured. | The duration of each build is visible; no target is set until the first delivery gives a baseline (A5). | TC1, R2 |

## Constraints

All constraints in the Ideation constraint register (TC1–TC8, OC1–OC5, RC1–RC5) stand.
Platform verification adds:

| ID | Constraint | Source |
|---|---|---|
| PC1 | Photo-based models built on the phone are limited to the platform's "reduced" detail level; higher levels need a Mac, which is unavailable. | V4 |
| PC2 | Fusion converts a mesh to a solid reliably only up to about 10,000 faces. | V11 |
| PC3 | Sensor code cannot run in the hosted build; it can only be compiled there. | V12 |
| PC4 | Depth formats, multi-camera combinations and exportable file types must be discovered on the phone at runtime. | V1, V6, V10 |
| PC5 | The hosted build machine has 7 GB of memory and 14 GB of disk. | V9 |

## Assumptions

| ID | Assumption | Rationale | Verified by |
|---|---|---|---|
| RA1 | Photo-based models carry true real-world size because the phone's depth sensor is used during capture. | Implied, not stated, by the platform documentation (V4). | FR-9 on the reference object. |
| RA2 | An app built with the current stable tools runs on the phone even if the phone is on a newer system version. | Normal forward compatibility (V7); inferred. | First delivery. |
| RA3 | Automatic matching of a scan to the reference shape is accurate enough that matching error is small compared with scan error. | Standard technique; not yet tried here. | FR-9.9 on synthetic data, then FR-9.3 on real scans. |
| RA4 | Reduced-detail models still resolve features of a few millimetres. | Unknown; this is the central risk (R1). | FR-9 on the reference object. |
| RA5 | Scheduled builds run on a public repository without the owner's action. | Standard feature of the build service. | FR-1.4. |

## Out of Scope

As set in the scope document:

- **Later:** measuring between two points in the app (B13); multi-camera offset
  correction (B14); colour on the model and room scanning, only if cheap (B15, B16).
- **Excluded:** editing or cleaning a scan in the app; the front depth camera; other
  users, invited testers or a public release; other devices; any server, account or
  sign-up.
- **Also excluded here:** rebuilding a model at higher detail *inside* the app from an
  exported raw capture. FR-7.5 only gets the raw capture out; what is done with it on a
  computer is outside this app.

## Origin Notes

One requirement did not come from Ideation and is recorded here as required by the
Inception traceability rule:

- **FR-7.5 Raw capture export** — introduced in this stage (Q8-A) in response to
  platform verification finding V4. Rebuilding on a computer needs separate software,
  which sits outside metric S4's "no third-party app" test; S4 is judged on the phone's
  own result.

## Open Questions

1. ~~Which system version is the owner's phone on?~~ **Resolved 2026-11-10: iOS 27.x** (owner's answer at the approval gate). Application Design sets NFR-1's minimum with this in hand; the stable build tools target iOS 26, the iOS 27 tools are a preview (V9).
2. Which matching method is used for the accuracy report, and what match-quality threshold marks a report unreliable (FR-9.3, FR-9.4)? For Application Design.
3. Does model building continue while the app is in the background, or pause and resume (FR-4.3)? To be observed on the phone.
4. Can the phone export file types beyond STL and OBJ natively (FR-7.6)? Read at runtime by FR-2.3.
5. What is the depth sensor's real minimum range (V2)? An S3 finding.
6. Which licence does the public repository carry (RAID I3)? Needed before the repository is published.
