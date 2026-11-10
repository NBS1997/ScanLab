# Performance Requirements — Bolt 1

Inputs: `unit-of-work.md` (U01, U02), `requirements.md` (FR-1, FR-10, NFR-1–12), `decisions.md` (ADR-001–016), `bolt-plan.md` (Bolt 1), `.claude/rules/aidlc-team.md`.

- Cold launch to the library visible: under 2 s on the phone (observed; launch logged).
- Logging an event never blocks the caller: writes happen off the main actor.
- Build loop (NFR-12): the duration of each CI run and each release is recorded; no
  target is set until a baseline exists.
