# Business Rules — U09 Capture Guidance, part 1: subject box and coverage dome

Inputs: owner feedback on build 7 (2026-11-12: "definitely better, more detail … we might
need a way to isolate the object so we can guide to get a full scan of it"; owner asked
for "another camera vision model like segmentation" and to "guide the user to scan
around the part"), `bolt-plan.md` (Bolt 10, part 1 brought forward as Bolt 10a),
`unit-of-work.md` (U09), U07 rules SC-1 to SC-13, U14 rules DF-1 to DF-10, ADR-029,
ADR-030.

## Choosing the subject

| ID | Rule | Origin |
|---|---|---|
| SB-1 | A sweep starts in "choose the subject": the camera runs, nothing is fused, and the screen says "Tap the part you want to scan." **Scan everything** skips the choice and fuses the whole view as in build 7. | owner feedback |
| SB-2 | A tap finds the subject from the next camera frame: the platform's subject-lifting vision request (Apple Vision, on the phone, no download) picks out the object under the tap in the colour picture, and the depth readings inside that outline become the subject's points. If Vision finds nothing there, the points within 15 cm sideways of the tapped point are used instead. | owner feedback ("segmentation") |
| SB-3 | The surface the subject sits on is the most common height among the nearby readings that are not the subject and lie below the tapped point (5 mm steps, at least 30 readings and 15% of them). It is cut away: the box's floor sits 2 mm above it. | SB-2 |
| SB-4 | The box spans the subject's points from the 2nd to the 98th percentile on each axis, plus 10% (at least 1 cm) on each side and 20% (at least 2 cm) on top, because the top is often seen least at first. Sides are kept between 4 cm and 1.5 m. The box is upright and lined up with the world's axes, not the part. | SB-2 |
| SB-5 | A tap fails, with a reason and nothing changed, when there is no depth where you tapped ("No depth there. Move closer, or tap another spot."), when the tap lands on the supporting surface ("That is the surface it sits on. Tap the part itself."), or when fewer than 40 readings belong to the subject ("Could not find the part there. Move closer, or tap another spot."). | SB-2 |
| SB-6 | A found box is drawn in yellow over the camera. **Scan this** locks it (it turns green); **Bigger** and **Smaller** change it by 10% (floor kept); tapping again finds a new box. | owner feedback |

## Scanning inside the box

| ID | Rule | Origin |
|---|---|---|
| SB-7 | Once locked, only cubes inside the box are fused, and readings landing outside it (plus the band) are skipped. The cubes are 3 mm, with a 12 mm band, because memory goes to the subject alone. | ADR-030 |
| SB-8 | Finish is available once the subject is locked (or Scan everything was chosen) and a surface exists. | SC-2 |

## Coverage dome

| ID | Rule | Origin |
|---|---|---|
| CD-1 | The views around the box are split into 24 directions: 8 around, at three heights (side 0–25°, raised 25–55°, above 55–90° looking down). Views from more than 10° below the box's centre count for nothing. | owner feedback |
| CD-2 | A fused picture counts for the direction the camera was in, when the box's centre is in the picture and the camera is within 1 m of it. A direction is covered after 3 such pictures. | CD-1 |
| CD-3 | The screen shows the dome as three rings of 8 (above in the middle, side outside); covered directions fill in, the camera's current direction is outlined. | CD-1 |
| CD-4 | The prompt points to the nearest uncovered direction: change height first ("Raise the phone and look down on it" / "Lower the phone to look at its side"), then go round ("Go round to your left" / "Go round to your right"). Once every direction is covered: "All round covered. Tap Finish when ready." Tracking and full-memory prompts come first. | CD-1 |
| CD-5 | When coverage first reaches every direction, the phone gives a success buzz. | U09 |

## Diagnostics

| ID | Rule | Origin |
|---|---|---|
| SB-9 | Logged under `capture`: tap result (box size in mm, floor found or not, mask used or not, readings, or the failure reason), Vision failures, box locked (size) or whole scene chosen, box resized, coverage at 50% and complete, and coverage at Finish. | project rule (diagnostics) |

**All numbers above are first guesses**, to be tuned on the phone.
