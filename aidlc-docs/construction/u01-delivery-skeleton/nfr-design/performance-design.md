# Performance Design — Bolt 1

Inputs: `unit-of-work.md` (U01, U02), `requirements.md` (FR-1, FR-10, NFR-1–12), `decisions.md` (ADR-001–016), `bolt-plan.md` (Bolt 1), `.claude/rules/aidlc-team.md`.

`FileLog` is an actor. `log` starts an unstructured task that hands the event to the
actor, so callers never wait on disk. The Diagnostics list reads at most the 500 most
recent events.
