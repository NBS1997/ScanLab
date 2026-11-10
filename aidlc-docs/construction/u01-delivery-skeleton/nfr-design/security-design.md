# Security Design — Bolt 1

Inputs: `unit-of-work.md` (U01, U02), `requirements.md` (FR-1, FR-10, NFR-1–12), `decisions.md` (ADR-001–016), `bolt-plan.md` (Bolt 1), `.claude/rules/aidlc-team.md`.

- `.gitignore` patterns for key material and build output, and a CI step that fails if
  any such file is tracked.
- Info.plist carries the camera purpose string and the encryption declaration.
- Core imports only Foundation; the App target uses no networking API in Bolt 1.
