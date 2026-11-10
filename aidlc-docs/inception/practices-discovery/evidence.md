# Practices Evidence — LidarApp

## What Was Scanned

Nothing. The project is greenfield: one commit, no source code, no build configuration.
The four-agent evidence scan applies to brownfield projects only and was skipped.

## What Was Inferred

| Area | Suggested from | Note |
|---|---|---|
| Way of Working | `aidlc-org.md` default (trunk-based, squash-merge) | Offered as the first option |
| Walking Skeleton | `aidlc-org.md` default; intent backlog items B1 and B2 | Scope definition already asked for a thin first version |
| Testing Posture | `aidlc-org.md` default (80% for `mvp`), adjusted for constraint TC3 (sensor behaviour can only be checked on the phone) | The adjusted option was offered first |
| Deployment | Constraint TC1 (no Mac; every trial is a build-and-deliver round trip) | Shortest loop offered first |
| Code Style | `aidlc-org.md` default (formatter and linter in CI, blocking) | Offered as the first option |

## What Was Asked

| Area | Answer |
|---|---|
| Way of Working | Trunk + squash-merge |
| Walking Skeleton | Yes, first and gated |
| Testing Posture | Split by testability |
| Deployment | Every merge to main |
| Code Style | Enforced in the build |
| Hard rules | No secrets in the repo; Diagnosable on the phone; Explain as you go; No paid or sign-up services |

Two rules in `discovered-rules.md` were derived rather than selected directly: the
on-device checklist rule follows from the testing answer, and the no-direct-commit rule
follows from the branching answer.
