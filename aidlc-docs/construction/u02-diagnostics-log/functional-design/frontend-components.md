# Frontend Components — U01 and U02

Inputs: `unit-of-work.md` (U01, U02), `requirements.md` (FR-1, FR-10, NFR-1–12), `decisions.md` (ADR-001–016), `bolt-plan.md` (Bolt 1), `.claude/rules/aidlc-team.md`.

| Component | Shows | Actions | States |
|---|---|---|---|
| LibraryView | Title "Scans"; empty state "No scans yet"; Diagnostics link | New scan arrives in Bolts 6 and 7 | Empty only, in Bolt 1 |
| DiagnosticsView | Version (build), build date, days to expiry; activity list, newest first | Export log (system share sheet) | Empty ("No activity yet"), filled; unreadable lines counted |

Accessibility: large titles as headings, labels on every control, Dynamic Type, both
orientations (checklist A1–A6, A12).
