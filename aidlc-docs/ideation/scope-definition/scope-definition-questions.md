# Scope Definition — Clarifying Questions

> Context: [intent-statement.md](../intent-capture/intent-statement.md) sets two equal
> threads (capturing real parts, exploring the hardware) and metrics S1–S4.
> [feasibility-assessment.md](../feasibility/feasibility-assessment.md) found the work
> feasible but small-part accuracy doubtful from the depth sensor alone, with photographs
> plus depth as the most promising route, and [constraint-register.md](../feasibility/constraint-register.md)
> records a slow build-and-deliver loop (TC1). These questions draw the boundary of the
> first version and set the order of work.

## Q1. What should the FIRST usable version let you do?
Everything else builds on this. A first delivery of an almost-empty app comes before it regardless, to prove the build pipeline.

- A. **See the hardware** — live views of what each sensor produces, with its reported characteristics. No scanning yet.
- B. **Scan and export** — capture a shape with the depth sensor and open the file on the computer. No explorer yet.
- C. **A thin slice of both** — one live sensor view, and one basic scan-to-file path.
- D. **Measure accuracy** — scan the reference object and get an error figure, with only as much else as that needs.
- X. Other (please specify)

[Answer]: C

## Q2. Which capture capabilities are MUST-HAVE for the MVP? (select all that apply)
Anything not selected becomes "later".

- A. **Depth-sensor scan** — sweep the phone around a medium or large subject to capture its shape.
- B. **Photograph-plus-depth capture** — many photographs of a small part, combined with depth for true size.
- C. **Edge detection** from the camera, shown over the live view or the scan.
- D. **Multi-camera offset correction** — combining cameras with different focal lengths.
- X. Other (please specify)

[Answer]: A, B, C

## Q3. Which supporting capabilities are MUST-HAVE for the MVP? (select all that apply)
- A. **Measure in the app** — pick two points on a scan and read the distance.
- B. **Accuracy report** — enter the reference object's caliper measurements and see scan error by feature.
- C. **Scan library** — keep, name, reopen and delete past scans on the phone.
- D. **Capture guidance** — feedback during capture on coverage and whether to slow down or move.
- E. **Export detail control** — choose how detailed the exported file is (for Fusion).
- X. Other (please specify)

[Answer]: B, C, D, E

## Q4. In what order should the work be sequenced?
- A. **Risk-first** — answer the biggest unknown (small-part accuracy) as early as possible, even if early versions are rough.
- B. **Value-first** — get a scan of a real part into Fusion as early as possible, then improve accuracy.
- C. **Exploration-first** — sensor views first, so later choices are informed by what you have seen.
- X. Other (please specify)

[Answer]: A

## Q5. How should the reference object come about?
- A. **Designed as part of this work, early** — a purpose-made object with a variety of shapes and sizes, which you print and measure.
- B. **Start with a simple known object** (for example, a printed calibration cube or a machinist's block), and design the purpose-made one later.
- C. **I will design it myself** outside this work; the app only needs to accept its measurements.
- X. Other (please specify)

[Answer]: A

## Q6. Which of these should be explicitly OUT of the MVP? (select all that apply)
- A. **Colour and surface appearance** on the model — shape only.
- B. **Editing or cleaning up a scan in the app** — that happens in Blender or Fusion.
- C. **Room and floor-plan scanning.**
- D. **The front (face-side) depth camera.**
- X. Other (please specify)

[Answer]: B, D

## Q7. (Follow-up) The accuracy report needs dimensions taken from the scan, but "measure in the app" is not a must-have. Where should the scan's dimensions come from?
- A. **Measure in the app** — promote point-to-point measuring to a must-have.
- B. **Measure in Fusion** and type the figures into the app's report.
- C. **Automatic comparison** — the app compares the scan with the reference object's known shape and reports error itself.
- X. Other (please specify)

[Answer]: C

## Q8. (Follow-up) Colour on the model and room/floor-plan scanning were not excluded in Q6 and are not must-haves. How should they be treated?
- A. **Later, if cheap** — not in the MVP plan; picked up afterwards only if they come almost free.
- B. **Colour in MVP**; room scanning later.
- C. **Both in MVP.**
- X. Other (please specify)

[Answer]: A
