# LidarApp — Architecture Decisions

Why things are the way they are. Before changing something that seems suboptimal, check
here first. **If a decision is documented below, it was deliberate** — don't refactor it
without raising the reversal explicitly.

Each entry is numbered permanently. IDs are referenced from commits and other docs, so
they are never reused and never renumbered.

---

_No decisions recorded yet (seeded 2026-11-10 into an empty repo). The first entries are
expected from the AIDLC inception: platform and language, scanning approach, export
formats, and the build and TestFlight pipeline. Add ADR-001 using the format in the
format below._

```markdown
## ADR-001: <short imperative title>

**Date:** YYYY-MM
**Status:** Active
**Context:** <what forced a choice: the constraint, the problem, the alternatives that lost>
**Decision:** <what was chosen, in one or two sentences>
**Consequence:** <what this costs and commits the project to, including the bad parts>
```

---

<!--
Copy the block above for each new decision. Statuses:
  Active               — in force
  Superseded by ADR-0NN — replaced; entry kept for the historical record
  Deprecated           — no longer applies, not replaced

Not everything needs an ADR. The test: would a competent newcomer look at this and
try to "fix" it? If yes, write the entry. If it is just a preference with no forcing
constraint, leave it out — a log full of trivia stops being read.
-->
