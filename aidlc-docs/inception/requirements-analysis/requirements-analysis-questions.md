# Requirements Analysis — Clarifying Questions

> Most requirements are already established by Ideation: the intent statement (metrics
> S1–S4), the scope document (13 capabilities), the constraint register and the rough
> mockups. These questions fill the gaps that would otherwise be guessed at when writing
> testable requirements.

## Q1. Where should an exported file go?
- A. **Ask each time** — the phone's standard "save to" chooser, so any folder (including cloud folders) can be picked.
- B. **A fixed cloud folder** — always the same folder, no prompt.
- C. **Fixed folder by default, with the chooser available** when I want somewhere else.
- X. Other (please specify)

[Answer]: A

## Q2. What is the largest footprint your 3D printer can produce?
This bounds the reference object's size.

- A. **About 180 × 180 mm.**
- B. **About 220–256 mm square.**
- C. **About 300 mm square or larger.**
- X. Other (please specify)

[Answer]: X — 340 mm × 320 mm × 340 mm

## Q3. Which kinds of feature matter most on the parts you design around? (select all that apply)
The reference object and the accuracy report will concentrate on these.

- A. **Overall lengths and distances between flat faces.**
- B. **Steps and heights** — small changes in level.
- C. **Holes and round bosses** — diameters and spacing.
- D. **Angles** between faces.
- E. **Curved surfaces** — radii and freeform shape.
- X. Other (please specify)

[Answer]: A, B, C, D, E

## Q4. Building a detailed model on the phone takes time. How long are you prepared to wait after finishing a capture?
- A. **Up to about 2 minutes.**
- B. **Up to about 10 minutes**, if the result is better.
- C. **As long as it takes**, provided progress is shown and I can leave the app.
- X. Other (please specify)

[Answer]: C

## Q5. Should the app keep the raw capture (photographs and depth data) after building the model?
Raw captures are large but allow a model to be rebuilt later at a different detail level.

- A. **Keep until I delete the scan.**
- B. **Keep only the model**; discard the raw capture once it is built.
- C. **Ask me each time.**
- X. Other (please specify)

[Answer]: C

## Q6. Which units should the app show?
- A. **Millimetres only.**
- B. **Millimetres, with metres for large subjects.**
- C. **Switchable between metric and inches.**
- X. Other (please specify)

[Answer]: B

## Q7. If a capture is interrupted (a phone call, switching apps, tracking lost for good), what should happen?
- A. **Keep what was captured** and let me finish or build from it.
- B. **Discard it and say so clearly**; I will start again.
- C. **Ask me** what to do when I return.
- X. Other (please specify)

[Answer]: A

## Q8. (Follow-up) The phone can only build photo-based models at reduced detail. Should the MVP also let you export the raw capture (photographs and camera positions) so a higher-detail model could be built on a computer later?
- A. **Raw export in MVP** — add raw-capture export now; rebuilding on a computer needs separate software the app does not provide.
- B. **Measure first** — not in the MVP; decide at the post-accuracy decision point.
- C. **No raw export** — the phone's own result is the product.
- X. Other (please specify)

[Answer]: A
