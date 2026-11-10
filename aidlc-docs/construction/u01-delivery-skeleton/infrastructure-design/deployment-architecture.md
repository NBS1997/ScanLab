# Deployment Architecture — Bolt 1

Inputs: `unit-of-work.md` (U01, U02), `requirements.md` (FR-1, FR-10, NFR-1–12), `decisions.md` (ADR-001–016), `bolt-plan.md` (Bolt 1), `.claude/rules/aidlc-team.md`.

```
Windows PC (agent)            GitHub (NBS1997/ScanLab, public)            Apple
git push ------------------>  ci.yml: secrets check, lint, format, Core tests, app compile
builder ios release -------->  ios-build.yml: XcodeGen, build, sign --+
   <---------------------------- IPA artifact ---------------------------+
   +-- upload (App Store Connect key stays on the PC) -----------------> App Store Connect
                                                                            +-> TestFlight -> phone
```

Text fallback: the agent pushes to GitHub, where `ci.yml` checks and tests. For a
delivery, `builder ios release` sends a snapshot to GitHub, where `ios-build.yml`
generates the project, builds and signs it, and returns the IPA; builder then uploads it
from the PC to App Store Connect, which makes it available in TestFlight on the phone.

Rollback: install an earlier build from the TestFlight app (builds stay available for 90
days); revert the squash commit on `main` and release again.
