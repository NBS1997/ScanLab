# Refined Mockups — Clarifying Questions

> Look, orientation, accessibility and the screen set were settled in the rough mockups
> (`wireframes.md`, `user-flow.md`) and carried into `stories.md` and `requirements.md`.
> The device is fixed, so responsive breakpoints reduce to upright and sideways. Three
> interaction choices remain.

## Q1. What kind of sound should capture guidance use?
- A. **Tones** — a short distinct sound per alert (too fast, tracking lost, coverage complete).
- B. **Spoken prompts** — a voice saying "slow down", "move back", "tracking lost".
- C. **Tones by default, spoken prompts as a setting.**
- X. Other (please specify)

[Answer]: A

## Q2. What should the accuracy report lead with, after match quality?
- A. **The summary** — typical error by feature kind and size class, with the per-feature table below.
- B. **The per-feature table** — every feature first, summary at the end.
- C. **A plain verdict** — one sentence such as "trust to about ±0.6 mm above 10 mm", then summary, then table.
- X. Other (please specify)

[Answer]: C

## Q3. How should errors be shown (a failed export, a failed model build, no storage)?
- A. **A message on the screen where it happened**, with the reason and what to do, and an entry in the log.
- B. **A brief banner** that fades, with details only in the log.
- C. **A message that must be dismissed**, plus a "View log" button.
- X. Other (please specify)

[Answer]: A
