# User Stories — LidarApp MVP

Sources: `requirements.md` (FR-1 to FR-10, NFR-1 to NFR-12), `personas.md`,
`team-practices.md` and the story plan (`user-stories-questions.md`): one person in three
modes (Q1-B), grouped by workflow (Q2-A), coarse granularity (Q3-A).

Each story is something the owner can try end to end on the phone. Acceptance criteria
are written so they can be used directly as the on-device checklist that
`team-practices.md` requires for each delivery.

## Story Map

| Group | Stories | Mode |
|---|---|---|
| Foundation | US-01, US-02 | Owner |
| See the hardware | US-03, US-04, US-05 | Explorer |
| Scan a part and use it | US-06, US-07, US-08, US-09, US-10, US-11 | Maker |
| Find out what to trust | US-12, US-13, US-14 | Checker |

## Foundation

### US-01 Get the app onto my phone
**As the** owner, **I want** each merged change built and delivered to my phone
automatically, **so that** I can try it without owning a Mac.

- **Priority:** Must. **Requirements:** FR-1.1, FR-1.2, FR-1.3, FR-1.4 (Should), NFR-4, NFR-12.
- **Acceptance criteria:**
  - Given a change is merged to `main`, when the build finishes, then a new build is offered in TestFlight on my phone.
  - Given the new build is installed, when I open the app, then it opens on the scan library.
  - Given the app is open, when I go to Diagnostics, then I see the version, build number, build date and days until expiry, and they match TestFlight.
  - Given no change has been merged for 60 days, when the schedule runs, then a fresh build arrives before the installed one expires. *(Should)*
- **Depends on:** nothing. **INVEST:** independent; small enough to be the first delivery; testable on the phone.

### US-02 See what the app has been doing
**As the** owner, **I want** an activity log I can read and export, **so that** problems
can be diagnosed from the phone.

- **Priority:** Must. **Requirements:** FR-10.1–10.4, NFR-8, NFR-9.
- **Acceptance criteria:**
  - Given I have used the app, when I open Diagnostics, then I see timestamped entries for what I did and for every error, with its reason.
  - Given entries exist, when I force-quit and reopen the app, then the entries are still there.
  - Given the log is shown, when I tap Export log, then I can save a text file with the same entries.
  - Given any later story is delivered, when I use its feature, then entries for it appear in the log.
- **Depends on:** US-01. **INVEST:** valuable on its own from the first delivery; the last criterion recurs in every later story.

## See the Hardware

### US-03 Watch the sensor live
**As the** Explorer, **I want** a live view with camera, depth and confidence layers I
can switch on and off, **so that** I can see what the sensor produces.

- **Priority:** Must. **Requirements:** FR-2.1 (camera, depth, confidence), FR-2.2, NFR-6, NFR-7.
- **Acceptance criteria:**
  - Given the Explore view is open, when I toggle camera, depth and confidence, then each shows alone and in any combination while the picture stays live.
  - Given I point the phone at a wall I have measured at 1.00 m, when I read the centre distance, then a value is shown in millimetres or metres.
  - Given all layers are on, when I move the phone, then the picture stays smooth, and the measured rate is written to the log.
  - Given I turn the phone sideways, when the view rotates, then all controls remain usable.
- **Depends on:** US-01. **INVEST:** independent of scanning; edges are a separate story (US-05).

### US-04 See what my phone reports and note what I find
**As the** Explorer, **I want** a list of what the phone itself reports about its sensors,
with a place for my notes, **so that** I build a first-hand record of its limits.

- **Priority:** Must. **Requirements:** FR-2.3, FR-2.4, FR-2.5, FR-2.6 (Should).
- **Acceptance criteria:**
  - Given Hardware details is open, when I read it, then I see depth formats and sizes, each rear camera with focal length and lens and offset data, which cameras can run together, and exportable file types.
  - Given a capability is listed, when I add a finding and reopen the app, then my finding is still there.
  - Given findings exist, when I tap Export findings, then I can save one text file containing every value and every finding.
  - Given the phone offers a higher-resolution depth still, when I capture one, then it is displayed with its size. *(Should)*
- **Depends on:** US-01. **INVEST:** small; delivers metric S3's record directly.

### US-05 See edges picked out
**As the** Explorer, **I want** edges detected from the camera shown over the live view
and over a scan, **so that** I can judge whether cameras add detail the depth sensor
misses.

- **Priority:** Must. **Requirements:** FR-2.1 (edges), FR-6.5.
- **Acceptance criteria:**
  - Given the Explore view is open, when I switch on Edges, then edges of objects in view are outlined live.
  - Given a scan is open, when I switch on Edges, then detected edges are shown with the model or its source picture.
  - Given Edges is on, when I look at a part with a sharp step, then I can record as a finding whether the step is picked out.
- **Depends on:** US-03, US-06 or US-07. **INVEST:** negotiable in presentation; testable by eye.

## Scan a Part and Use It

### US-06 Sweep-scan something larger
**As the** Maker, **I want** to sweep the phone over a medium or large subject and get a
3D model, **so that** I capture overall shape at true size.

- **Priority:** Must. **Requirements:** FR-3.1–3.3, FR-6.4.
- **Acceptance criteria:**
  - Given I choose Sweep, when I move the phone over a subject at least 0.5 m across and tap Finish, then a model is shown.
  - Given the model is shown, when I look at scan detail, then I can turn and zoom it and see its face count and overall dimensions.
  - Given a capture is running, when I rotate the phone, then the capture continues.
  - Given I finish, when I return to the library, then the scan is there without a save step.
- **Depends on:** US-01. **INVEST:** independent of photo capture.

### US-07 Photo-scan a small part
**As the** Maker, **I want** to photograph a small part from all round and have the phone
build a model, **so that** I get finer detail than the depth sensor alone.

- **Priority:** Must. **Requirements:** FR-4.1–4.4, FR-6.6.
- **Acceptance criteria:**
  - Given I choose Photos with no network connection, when I capture an object under 150 mm and tap Finish, then a model is built on the phone.
  - Given the model is building, when I watch, then progress updates at least every 10 seconds; and when I switch to another app and back, the build completes or resumes without recapturing.
  - Given the model is built, when I open scan detail, then I see which detail level was used and the overall dimensions in millimetres.
  - Given the model is built, when asked whether to keep the raw capture, then I see how much storage it uses and my choice is honoured.
- **Depends on:** US-01. **INVEST:** the largest story; kept whole because a partial photo capture is not worth a delivery.

### US-08 Be guided while I capture
**As the** Maker, **I want** to feel and hear when I am going wrong and see what I have
covered, **so that** I get a usable scan without watching the screen.

- **Priority:** Must. **Requirements:** FR-5.1–5.3.
- **Acceptance criteria:**
  - Given a capture is running, when I cover the camera or move too fast, then within one second the phone taps and sounds.
  - Given a capture is running, when I glance at the screen, then captured areas are marked and a coverage indication has grown since I started.
  - Given the screen reader is on, when tracking is lost, then the alert is spoken.
- **Depends on:** US-06, US-07. **INVEST:** applies to both capture methods; testable by acting it out.

### US-09 Not lose a capture when interrupted
**As the** Maker, **I want** an interrupted capture kept, **so that** a phone call does
not cost me the work.

- **Priority:** Must. **Requirements:** FR-5.4, NFR-8.
- **Acceptance criteria:**
  - Given a capture is running, when I switch to another app and return, then I am offered Continue and Build from what I have.
  - Given I choose Build, when it finishes, then a model is produced from the partial capture.
  - Given any interruption, when I open the library, then scans saved earlier are intact.
- **Depends on:** US-06, US-07. **INVEST:** small; one behaviour.

### US-10 Keep and manage my scans
**As the** Maker, **I want** a library of my scans that I can rename and delete, **so
that** past work is there when I need it.

- **Priority:** Must. **Requirements:** FR-6.1–6.3, NFR-9.
- **Acceptance criteria:**
  - Given scans exist, when I open the app, then each shows a thumbnail, name, method, date and size, and a mark if it has an accuracy report.
  - Given a scan, when I rename it and reopen the app, then the new name is kept.
  - Given a scan, when I delete it and confirm, then it is gone and its storage is freed.
  - Given scans exist, when I install a newer build, then they are all still there.
- **Depends on:** US-06 or US-07. **INVEST:** independent of export.

### US-11 Get a scan into my design tools
**As the** Maker, **I want** to export a scan at a chosen level of detail to wherever I
choose, **so that** it opens in Fusion, Blender or a slicer at true size with no other
service involved.

- **Priority:** Must (3MF: Could). **Requirements:** FR-7.1–7.6, NFR-2, NFR-3.
- **Acceptance criteria:**
  - Given a scan, when I tap Export, then I choose STL or OBJ and one of Full, Fusion-friendly or Light, with the face count of each shown.
  - Given I confirm, when the chooser appears, then I can save to a cloud folder I can open on my Windows computer.
  - Given a Fusion-friendly export, when I insert it in Fusion, then it has 10,000 faces or fewer, converts to a solid, and its overall dimensions match the app's to within 0.1%.
  - Given the same file, when I open it in Blender and in a slicer, then it loads at the same size.
  - Given a photo scan whose raw capture was kept, when I export the raw capture, then the folder holds every photograph and a file of camera positions.
  - Given the phone is in aeroplane mode, when I export to on-phone storage, then it succeeds.
- **Depends on:** US-06 or US-07. **INVEST:** metric S4 is judged on this story.

## Find Out What to Trust

### US-12 Print and measure a reference object
**As the** Checker, **I want** a purpose-made reference object to print and a sheet to
record its real dimensions, **so that** there is a known truth to compare scans with.

- **Priority:** Must. **Requirements:** FR-8.1–8.6.
- **Acceptance criteria:**
  - Given the design files in the repository, when I load the printable file in my slicer, then it fits my 340 × 320 × 340 mm printer.
  - Given the printed object, when I look at it, then it has lengths, steps, holes and bosses, angles and curves, each at three or more sizes, and it looks different from every side.
  - Given the measurement sheet, when I measure with calipers, then every listed feature has an identifier, an instruction and a design value to compare with.
  - Given my measurements, when I enter them in the app and reopen it, then they are kept and can be edited.
- **Depends on:** US-01 for the last criterion only; the design and print need no app. **INVEST:** independent; has a physical lead time, so it starts early.

### US-13 Get an accuracy report I can believe
**As the** Checker, **I want** the app to compare a scan of the reference object with its
known shape and tell me the error and how reliable the comparison is, **so that** I know
what each capture method can be trusted for.

- **Priority:** Must. **Requirements:** FR-9.1–9.6, FR-9.9, NFR-10.
- **Acceptance criteria:**
  - Given a scan marked as the reference object, when I tap Check accuracy, then a report appears without my picking any points.
  - Given the report, when I read it, then match quality (a number and a plain rating) comes first.
  - Given a scan of some other object marked as the reference, when I check it, then the report says the result is unreliable and shows no accuracy figures.
  - Given a good match, when I read on, then each measured feature shows caliper value, scanned value and difference, followed by typical error by feature kind and by size class.
  - Given the build's automated tests, when a synthetic scan with a known built-in error is checked, then the reported error matches to within 0.05 mm.
- **Depends on:** US-12, and US-06 or US-07. **INVEST:** metrics S1 and S2 are judged on this story; the last criterion is checked in the build, not on the phone.

### US-14 Compare methods and keep the numbers
**As the** Checker, **I want** to compare reports from different capture methods and
export them, **so that** I can decide which method to use and what to do next.

- **Priority:** Must. **Requirements:** FR-9.7, FR-9.8.
- **Acceptance criteria:**
  - Given reports for the same reference object from a sweep scan and a photo scan, when I tap Compare methods, then both are shown side by side by feature kind and size class.
  - Given a report, when I export it, then the file opens in a spreadsheet with one row per feature.
- **Depends on:** US-13. **INVEST:** small; feeds the decision point the backlog sets after the accuracy work.

## Coverage

| Requirement group | Stories |
|---|---|
| FR-1 Delivery and app shell | US-01 |
| FR-2 Hardware exploration | US-03, US-04, US-05 |
| FR-3 Sweep capture | US-06 |
| FR-4 Photo capture | US-07 |
| FR-5 Guidance and interruption | US-08, US-09 |
| FR-6 Library and scan detail | US-05, US-06, US-07, US-10 |
| FR-7 Export | US-11 |
| FR-8 Reference object | US-12 |
| FR-9 Accuracy report | US-13, US-14 |
| FR-10 Diagnostics | US-02 |

Non-functional requirements NFR-1 (platform), NFR-5 (cost), NFR-10 (testability) and
NFR-11 (maintainability) apply to every story and are checked by the build and by review
rather than by a story's acceptance criteria.

## Sequencing Note

The story map is grouped by workflow, as chosen. The order of delivery remains the
risk-first backlog sequence: US-01 → US-03 and US-06 with a first cut of US-11 (the thin
first version), US-12 alongside → US-02 → US-07 → US-13, US-14 → then US-11 in full,
US-08, US-09, US-10, US-05, US-04. Delivery Planning sets the final order.
