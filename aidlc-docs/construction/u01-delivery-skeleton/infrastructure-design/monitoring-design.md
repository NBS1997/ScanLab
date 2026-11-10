# Monitoring Design — Bolt 1

Inputs: `unit-of-work.md` (U01, U02), `requirements.md` (FR-1, FR-10, NFR-1–12), `decisions.md` (ADR-001–016), `bolt-plan.md` (Bolt 1), `.claude/rules/aidlc-team.md`.

- CI and build status: GitHub Actions run pages; builder prints the run address.
- App behaviour: the in-app diagnostics log (U02), exported by the owner when needed.
- Build expiry: days remaining on the Diagnostics screen; a monthly reminder on the PC.
