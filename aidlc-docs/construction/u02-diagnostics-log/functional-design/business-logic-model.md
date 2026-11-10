# Business Logic Model — U02 Diagnostics Log

Inputs: `unit-of-work.md` (U01, U02), `requirements.md` (FR-1, FR-10, NFR-1–12), `decisions.md` (ADR-001–016), `bolt-plan.md` (Bolt 1), `.claude/rules/aidlc-team.md`.

```
any component --LogEvent--> Logging (port, Core)
                               |
                 FileLog (adapter, App): encode -> append line -> flush
                               |
     Diagnostics screen: recent(limit) -> list;  exportText() -> share sheet
```

Text fallback: components send events to the Logging port; the file adapter encodes each
as a JSON line and appends it; the Diagnostics screen reads recent events for the list
and the whole log as text for export.

- **Core** owns `LogEvent`, encoding and tolerant decoding (`LogCodec`), trimming
  (`LogTrimmer`), export text (`LogFormatter`) and `BuildInfo` expiry arithmetic. All are
  tested in the build.
- **App** owns the file location (Application Support/Logs/scanlab.log), the file I/O
  and the mirror to the system log.
