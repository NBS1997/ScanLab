# Intent Backlog — LidarApp MVP

Sources: [scope-document.md](scope-document.md),
[intent-statement.md](../intent-capture/intent-statement.md),
[feasibility-assessment.md](../feasibility/feasibility-assessment.md) and
[constraint-register.md](../feasibility/constraint-register.md).

Prioritised with MoSCoW. Sequenced **risk-first** (scope Q4): items that answer the
largest unknowns come before items that add polish. Each item is a proto-Unit, to be
refined into Units during Inception.

## Prioritised Backlog

| Seq | ID | Item | MoSCoW | Risk it retires | Depends on | Metric |
|---|---|---|---|---|---|---|
| 1 | B1 | Almost-empty app built and delivered to the phone | Must | Build pipeline does not work for this app (R8) | — | All |
| 2 | B2 | First usable version: one live depth view, one basic depth-sensor scan, export to a file that opens on the computer | Must | End-to-end path is not achievable; file does not open in the owner's tools (R5) | B1 | S3, S4 |
| 2 | B3 | Reference object designed, for the owner to print and measure (off the phone, alongside B2) | Must | No basis for any accuracy figure | — | S1 |
| 3 | B4 | Built-in diagnostics: the app shows and exports what it is doing | Must | Faults cannot be found without a Mac (R2) | B1 | All |
| 4 | B5 | Photograph-plus-depth capture of a small part, exported to a file | Must | Small-part accuracy falls short (R1); the platform capability does not behave as assumed (R4) | B2 | S1, S2 |
| 5 | B6 | Automatic accuracy report against the reference object, for both capture methods | Must | Accuracy is unknown; matching scan to reference is unreliable (scope boundary risk) | B2, B3, B5 | S1, S2 |
| 6 | B7 | Export detail control, checked with a real scan in Fusion | Must | Scans too detailed for Fusion (R5) | B2 | S4 |
| 7 | B8 | Capture guidance: coverage and movement feedback | Must | Capture stays frustrating | B2, B5 | S2 |
| 8 | B9 | Scan library: keep, name, reopen, delete | Must | — | B2 | S4 |
| 9 | B10 | Edge detection from the camera, shown over the live view or the scan | Must | Edges cannot be tied to real positions usefully | B2 | S3 |
| 10 | B11 | Hardware findings: every sensing capability exercised, limits written down | Must | Hardware remains a black box | B2, B5, B10 | S3 |
| 11 | B12 | Regular rebuild and redelivery so the app does not expire | Should | App stops opening (R9) | B1 | S4 |
| — | B13 | Measuring between two points in the app | Won't (this time) | — | B2 | — |
| — | B14 | Multi-camera offset correction | Won't (this time) | — | B6 results | — |
| — | B15 | Colour and surface appearance on the model | Could, if cheap | — | B5 | — |
| — | B16 | Room and floor-plan scanning | Could, if cheap | — | B2 | — |

## Sequencing Rationale

1. **B1 first.** Until an app reaches the phone, nothing can be learned. Keeping it
   almost empty means a failure here is a pipeline fault, not an app fault.
2. **B2 is the walking skeleton the owner asked for** (scope Q1-C): thin, end to end, and
   expected to be rough. B3 runs alongside because it needs no app and has a print-and-
   measure lead time.
3. **B4 early** because every later item is harder to diagnose without it.
4. **B5 then B6** are the risk-first core. Together they answer the question the whole
   initiative turns on: can a small part be scanned accurately enough to design against?
   If the answer is no, the owner learns it before investing in B7–B11.
5. **B7–B11** improve a path already known to work, in descending order of the risk each
   retires.

## Decision Point After B6

Once accuracy figures exist for both capture methods, the owner decides, with numbers:

- whether the tolerance for S2 is acceptable for the parts they care about;
- whether B14 (multi-camera correction) is worth bringing forward;
- whether to continue with B7–B11 as planned or redirect effort.

## Dependencies Outside the Backlog

- Signing secrets configured for the new repository (feasibility dependency D3) — needed for B1.
- The build-and-deliver workflow from the Nathans Fishing App repository (D4) — needed for B1.
- The owner prints and measures the reference object (D5) — needed for B6.
