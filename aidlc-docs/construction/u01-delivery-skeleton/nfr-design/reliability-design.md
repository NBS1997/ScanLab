# Reliability Design — Bolt 1

Inputs: `unit-of-work.md` (U01, U02), `requirements.md` (FR-1, FR-10, NFR-1–12), `decisions.md` (ADR-001–016), `bolt-plan.md` (Bolt 1), `.claude/rules/aidlc-team.md`.

- Append: open the file for writing, seek to the end, write the line, synchronise.
- Trimming writes the kept lines to a temporary file, then replaces the log atomically.
- Decoding skips bad lines and reports how many were skipped (BR-3).
