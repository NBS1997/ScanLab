# Project-Level Rules

> Project-specific overrides and corrections. Overrides aidlc-team.md
> and aidlc-org.md. Populated by practices-discovery and the
> self-learning loop.
>
> Use sparingly: most teams don't need a project layer. Reach for it
> only when this specific project deviates from team-wide practice in a
> stable, durable way (e.g., "this monorepo project rebases even though
> our team default is squash"; "this legacy project skips the test
> floor because the existing suite is unsalvageable and we accept
> that").

## Way of Working

<!-- Project-specific override. Example: -->
<!-- This monorepo project rebases instead of squash-merging because -->
<!-- the per-package commit history is the audit trail we depend on -->
<!-- for partial-rollback decisions. Override applies to this project -->
<!-- only. -->

## Walking Skeleton

<!-- Project-specific override. Example: -->
<!-- This project skips the walking skeleton because we're rewriting -->
<!-- an existing service in-place — there's no greenfield bootstrap -->
<!-- to gate. -->

## Testing Posture

<!-- Project-specific override. -->

## Deployment

<!-- Project-specific override. -->

## Code Style

<!-- Project-specific override. -->

## Tech Stack

<!-- Technology choices locked for this project. -->

## Decided

<!-- Decisions made in earlier stages that should not be re-asked. -->
<!-- Format: DECIDED: [decision] (Stage [slug], [date]) -->

## Scope Overrides

<!-- Custom scope rules for this project. -->

## Forbidden

<!-- Populated by practices-discovery affirmation gate. -->
<!-- Format: NEVER [behavior] (affirmed [date]) -->
<!-- Example: NEVER throw exceptions across service layer boundaries (affirmed 2026-05-17) -->

NEVER commit signing keys, certificates or credentials; the repository is public (affirmed 2026-11-10)
NEVER add a dependency or service that costs money or requires an account or sign-up (affirmed 2026-11-10)
NEVER commit directly to main after the initial commit (affirmed 2026-11-10)
## Mandated

<!-- Populated by practices-discovery affirmation gate. -->
<!-- Format: ALWAYS [behavior] (affirmed [date]) -->
<!-- Example: ALWAYS use Result<T,E> for fallible operations in service layer (affirmed 2026-05-17) -->

ALWAYS make new behaviour visible in the app's built-in diagnostics, because there is no Mac to debug from (affirmed 2026-11-10)
ALWAYS explain non-obvious code in plain language, because the owner relies on AI-written code (affirmed 2026-11-10)
ALWAYS provide an on-device checklist with any delivery that changes sensor-dependent behaviour (affirmed 2026-11-10)
## Corrections

<!-- Project-specific corrections from human feedback. -->
<!-- Format: NEVER/ALWAYS [behavior] (learned [date]) -->
