# Logical Components — Bolt 1

Inputs: `unit-of-work.md` (U01, U02), `requirements.md` (FR-1, FR-10, NFR-1–12), `decisions.md` (ADR-001–016), `bolt-plan.md` (Bolt 1), `.claude/rules/aidlc-team.md`.

| Component | Package | Role |
|---|---|---|
| `LogEvent`, `LogLevel` | Core | Event model |
| `Logging` (protocol) | Core | Port used everywhere |
| `LogCodec`, `LogTrimmer`, `LogFormatter` | Core | JSON-line coding, trimming, export text |
| `BuildInfo` | Core | Version, build, date and expiry arithmetic |
| `FileLog` | App | File adapter with system-log mirror |
| `BundleBuildInfo` | App | Reads Info.plist into `BuildInfo` |
| `AppEnvironment` | App | Composition root |
| `LibraryView`, `DiagnosticsView`, `DiagnosticsModel` | App | Screens |
