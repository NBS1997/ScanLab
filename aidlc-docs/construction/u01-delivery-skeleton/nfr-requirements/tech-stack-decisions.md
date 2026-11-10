# Tech Stack Decisions — Bolt 1

Inputs: `unit-of-work.md` (U01, U02), `requirements.md` (FR-1, FR-10, NFR-1–12), `decisions.md` (ADR-001–016), `bolt-plan.md` (Bolt 1), `.claude/rules/aidlc-team.md`.

| Area | Choice | Reason |
|---|---|---|
| Language | Swift 6 (language mode 6) | ADR-001 |
| UI | SwiftUI with Observation | ADR-001 |
| Tools | Xcode 26 on `macos-latest` (macOS 26); minimum iOS 26.0 | ADR-002 |
| Project | XcodeGen `project.yml`; local Swift package `Packages/ScanLabCore` | ADR-003, ADR-004 |
| Tests | Swift Testing in the Core package; `swift test --enable-code-coverage` on macOS | NFR-10 |
| Lint | SwiftLint with a custom rule banning `print(` and `NSLog(` | ADR-008, BR-8 |
| Format | `swift format lint --strict` (ships with the Swift toolchain) | Team practice |
| Delivery | builder CLI v0.11.0: `ios-build.yml` on GitHub builds and signs; `builder ios release` uploads from Windows | ADR-016 |
