# Business Rules — U02 Diagnostics Log

Inputs: `unit-of-work.md` (U01, U02), `requirements.md` (FR-1, FR-10, NFR-1–12), `decisions.md` (ADR-001–016), `bolt-plan.md` (Bolt 1), `.claude/rules/aidlc-team.md`.

| ID | Rule | Requirement |
|---|---|---|
| BR-1 | Every event is appended and flushed to disk before the write completes. | FR-10.2 |
| BR-2 | On launch the log is trimmed to the most recent 5,000 lines (at least the 1,000 required). | FR-10.2 |
| BR-3 | A line that cannot be decoded is skipped when reading, and counted; the count is shown. | NFR-8 |
| BR-4 | Logging never throws to its caller. A failed write is counted and reported with the next successful write. | FR-10.1 |
| BR-5 | The export is plain text, one line per event: time, level, category, message, details. | FR-10.3 |
| BR-6 | Days to expiry = whole days from now to `expiryDate`, never negative; "expired" at 0. | FR-1.3 |
| BR-7 | App launch is always logged with version and build. | US-02 |
| BR-8 | No direct console printing in app or Core code; a lint rule enforces it. | FR-10.4, ADR-011 |
