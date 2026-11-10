# Domain Entities — U02 Diagnostics Log

Inputs: `unit-of-work.md` (U01, U02), `requirements.md` (FR-1, FR-10, NFR-1–12), `decisions.md` (ADR-001–016), `bolt-plan.md` (Bolt 1), `.claude/rules/aidlc-team.md`.

## LogEvent

| Field | Type | Rule |
|---|---|---|
| `timestamp` | Date (UTC) | Set when the event is created |
| `level` | `info` · `warning` · `error` | `error` for every failure surfaced to the owner |
| `category` | String | Area of the app: `app`, `log`, `build`; later `capture`, `export` and so on |
| `message` | String | Plain words; no file contents, photographs or secrets (ADR-011) |
| `details` | [String: String] | Small key–value context (counts, durations, reasons) |

Encoded as one JSON object per line.

## BuildInfo

| Field | Source | Rule |
|---|---|---|
| `version` | `CFBundleShortVersionString` | Shown as "version (build)" |
| `build` | `CFBundleVersion` | Stamped by builder at release |
| `buildDate` | `SLBuildDate`, written into Info.plist by a build phase | ISO 8601 UTC; absent in local previews |
| `expiryDate` | `buildDate` + 90 days | TestFlight build lifetime (V8) |
