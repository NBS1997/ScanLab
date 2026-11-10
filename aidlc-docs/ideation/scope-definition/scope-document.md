# Scope Document — LidarApp MVP

Sources: [intent-statement.md](../intent-capture/intent-statement.md) (metrics S1–S4),
[feasibility-assessment.md](../feasibility/feasibility-assessment.md),
[constraint-register.md](../feasibility/constraint-register.md) and
[scope-definition-questions.md](scope-definition-questions.md) (Q1–Q8).

## Scope Summary

A personal scanning app for the owner's iPhone 17 Pro Max that captures real objects two
ways (a depth-sensor sweep, and photographs combined with depth), reports how accurate
its own scans are against a purpose-made reference object, and exports files the owner's
tools open directly. Work is sequenced **risk-first** (Q4): the unknown that could
undermine the whole idea, small-part accuracy, is answered as early as possible.

## In Scope

| # | Capability | Why it is in | Serves |
|---|---|---|---|
| 1 | **Build and delivery to the phone**, proven with an almost-empty app first | Nothing else can be tried without it; separates pipeline faults from app faults | All |
| 2 | **Live sensor view** — see what the depth sensor produces as it happens | First usable version (Q1-C); start of hardware exploration | S3 |
| 3 | **Depth-sensor scan** of medium and large subjects | Must-have (Q2-A); first usable version (Q1-C) | S2, S4 |
| 4 | **Export to a file** that opens in Fusion, Blender and a slicer, saved where the owner's computer can reach it | First usable version (Q1-C); feasibility constraint TC5, TC6 | S4 |
| 5 | **Reference object** — a purpose-made design with a variety of shapes and sizes, for the owner to print and measure | Q5-A; the basis of every accuracy figure | S1 |
| 6 | **Photograph-plus-depth capture** of small parts | Must-have (Q2-B); feasibility names it the most promising route for small parts | S1, S2 |
| 7 | **Automatic accuracy report** — the app compares a scan of the reference object with its known shape and reports the error, with no manual measuring | Must-have (Q3-B, Q7-C) | S1, S2 |
| 8 | **Export detail control** — choose how detailed the exported file is | Must-have (Q3-E); Fusion struggles with very detailed scans | S4 |
| 9 | **Scan library** — keep, name, reopen and delete scans on the phone | Must-have (Q3-C) | S4 |
| 10 | **Capture guidance** — feedback during capture on coverage and movement | Must-have (Q3-D); the capture process was a named pain point | S2 |
| 11 | **Edge detection** from the camera, shown over the live view or the scan | Must-have (Q2-C) | S3 |
| 12 | **Hardware findings** — each sensing capability exercised through the app, with its limits written down | Success metric S3 | S3 |
| 13 | **Built-in diagnostics** — the app shows and exports what it is doing | Feasibility: with no Mac, faults must be diagnosable from the phone (TC1) | All |

## Out of Scope

**Later** — wanted, but not in this MVP:

| Capability | Decision | Note |
|---|---|---|
| Measuring between two points in the app | Later (Q3-A not selected) | The automatic accuracy report replaces the need for it in the MVP (Q7-C). |
| Multi-camera offset correction | Later (Q2-D not selected) | Feasibility rates it the most complex item (risk R3). Revisit with accuracy figures in hand. |
| Colour and surface appearance on the model | Later, if cheap (Q8-A) | Included only if it comes almost free with what is built. |
| Room and floor-plan scanning | Later, if cheap (Q8-A) | As above. |

**Excluded** — not planned at all:

| Capability | Decision |
|---|---|
| Editing or cleaning up a scan in the app | Out (Q6-B). That happens in Blender or Fusion. |
| The front (face-side) depth camera | Out (Q6-D). |
| Other users, invited testers, a public release | Out. Single user (intent statement). |
| Other phones or tablets | Out. One device (constraint TC2). |
| Any server, account or sign-up | Out (constraints TC6, RC5). |

## Scope Boundary Decisions

- **The accuracy report is automatic** (Q7-C). The owner chose the option flagged as the
  hardest to build. *Risk:* lining a scan up with the reference object's known shape is
  itself a source of error, so the report must show how well the two were matched, or
  its figures cannot be trusted. This is an addition to the risks in the feasibility
  RAID log.
- **The reference object must suit automatic comparison.** Its design needs features the
  app can match unambiguously, and the owner's caliper measurements of the printed object
  must be able to correct the design dimensions (feasibility: the printed object, not the
  design, is the truth).
- **"First usable version" is deliberately thin** (Q1-C): one live view and one basic
  scan-to-file path. It is expected to be rough.
- **No date applies** (feasibility Q9). The plan is validated against learning value, not
  a timeline, so there is no scope-versus-deadline conflict to resolve.

## Value Stream

How a real part becomes a trusted model, and where each in-scope capability sits. The
previous third-party experience broke at the steps marked ✗.

```
Pick up phone → Capture → Check the scan → Export → Transfer → Open in design tool → Design against it
                  ✗            ✗             ✗         ✗                               ✗
```

| Step | Old pain (intent statement) | Capability that addresses it |
|---|---|---|
| Capture | Tracking loss, re-scans, no coverage feedback | 3, 6, 10 |
| Check the scan | Too coarse; no idea whether to trust it | 7, 11, 12 |
| Export | Formats and paywalls | 4, 8 |
| Transfer | Sign-ups to other services to get the file | 4 |
| Design against it | Dimensions could not be relied on | 5, 7 |

Text fallback: the flow is seven steps in a line, from picking up the phone to designing
against the scan; capture, checking, export, transfer and designing were the failure
points before.
