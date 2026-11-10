# Reliability Requirements — Bolt 1

Inputs: `unit-of-work.md` (U01, U02), `requirements.md` (FR-1, FR-10, NFR-1–12), `decisions.md` (ADR-001–016), `bolt-plan.md` (Bolt 1), `.claude/rules/aidlc-team.md`.

- Log entries survive force-quit and crash (flush on write, BR-1).
- A corrupt log line never prevents the Diagnostics screen from opening (BR-3).
- The installed build never silently expires: days to expiry are shown (FR-1.3). The
  monthly rebuild (FR-1.4) becomes a scheduled reminder on the PC under ADR-016.
