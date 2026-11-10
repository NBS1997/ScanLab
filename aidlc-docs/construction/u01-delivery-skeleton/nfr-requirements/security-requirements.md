# Security Requirements — Bolt 1

Inputs: `unit-of-work.md` (U01, U02), `requirements.md` (FR-1, FR-10, NFR-1–12), `decisions.md` (ADR-001–016), `bolt-plan.md` (Bolt 1), `.claude/rules/aidlc-team.md`.

- SR-1 No signing key, certificate, profile or App Store Connect key in the repository
  (NFR-4). Key material lives outside the repository in the owner's user folder and in
  builder's credential store; `.gitignore` blocks `*.p12`, `*.key`, `*.p8`,
  `*.mobileprovision` and `dist/`.
- SR-2 Signing secrets exist only in the repository's secret store; workflows never echo
  them, and pull requests from forks do not receive them (GitHub default).
- SR-3 The app makes no network requests (NFR-3); no analytics or crash service.
- SR-4 `ITSAppUsesNonExemptEncryption` is NO (RC3); the camera purpose string is present (RC1).
- SR-5 Log events never contain file contents or secrets (ADR-011).
