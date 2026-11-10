# Delivery Planning — Questions

> Inputs: `unit-of-work.md`, `unit-of-work-dependency.md`, `unit-of-work-story-map.md`,
> `requirements.md`, `stories.md`, the Application Design artefacts, and
> `.claude/rules/aidlc-team.md`.
>
> Already decided, so not asked again:
> - **Heuristic:** risk-first (scope definition Q4-A), with a gated walking skeleton first
>   (team practices). No WSJF scoring: one owner, no competing value streams.
> - **Parallel Bolts:** allowed where the dependency graph permits (units Q3-A).
> - **Mob:** every Bolt is built by the developer agent (team formation is out of `mvp`
>   scope).
>
> Proposed sequence (one Unit per Bolt, except the walking skeleton):
>
> | Step | Bolts | Units |
> |---|---|---|
> | 1 | Bolt 1 — walking skeleton (solo, gated) | U01 + U02 |
> | 2 | Bolts 2, 3, 4 in parallel | U03 reference object, U04 geometry and export, U06 live view |
> | 3 | Bolt 5 | U05 scan library |
> | 4 | Bolts 6, 7, 8 in parallel | U07 sweep capture, U08 photo capture, U10 accuracy stage 1 |
> | — | **Decision point:** first accuracy numbers for both capture methods | |
> | 5 | Bolts 9, 10 in parallel | U11 accuracy stage 2, U09 guidance and interruption |
> | 6 | Bolts 11, 12 in parallel | U12 edge detection, U13 hardware details |

## Q1. Is this Bolt sequence right?
- A. **Yes, as proposed.**
- B. **Hardware details earlier** — move U13 into step 3, so the phone's real capabilities are known before capture is built.
- C. **Strictly one Bolt at a time**, in the order shown.
- X. Other (please specify)

[Answer]: A

## Q2. Should the decision point after step 4 always stop for you, even if you later choose to let Bolts run without gates?
- A. **Yes, always stop** — review the accuracy numbers and decide whether to continue as planned, bring multi-camera work forward, or redirect.
- B. **No** — follow whatever gate mode is chosen after the walking skeleton.
- X. Other (please specify)

[Answer]: B

## Q3. Who creates the public GitHub repository and pushes to it?
The walking skeleton cannot be delivered until the code is on GitHub.

- A. **The agent, using the GitHub command-line tool**, at the start of Construction, after asking you to confirm the repository name.
- B. **I will create it myself** and tell the agent when it exists.
- X. Other (please specify)

[Answer]: A
