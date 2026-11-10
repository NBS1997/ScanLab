# Infrastructure Services — Bolt 1

Inputs: `unit-of-work.md` (U01, U02), `requirements.md` (FR-1, FR-10, NFR-1–12), `decisions.md` (ADR-001–016), `bolt-plan.md` (Bolt 1), `.claude/rules/aidlc-team.md`.

| Service | Use | Cost |
|---|---|---|
| GitHub Actions, `macos-latest` | CI checks and signed builds | Free (public repository) |
| GitHub repository secrets | `IOS_CERTIFICATE_STORE`, `IOS_CERTIFICATE_PASSWORD_STORE`, `IOS_PROVISIONING_PROFILE_STORE`, `IOS_EXTENSION_PROFILES_STORE` | Free |
| App Store Connect and TestFlight | Upload and internal testing | Existing membership |
| builder CLI on the PC | Snapshot builds, signing, upload | Existing tool |
