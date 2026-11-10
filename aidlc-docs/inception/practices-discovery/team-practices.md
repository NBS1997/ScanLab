# Team Practices — LidarApp

Affirmed by the owner in the Practices Discovery interview, 2026-11-10. "We" is a team of
one person working with AI agents.

## Way of Working

We use trunk-based development on `main` with short-lived branches, and we squash-merge
each Bolt into `main` as a single commit named by the Bolt slug. Nothing is committed to
`main` directly after the initial commit.

## Walking Skeleton

We always run the walking skeleton first and gate it: an almost-empty app built and
delivered to the phone through TestFlight, then the thin first version (one live sensor
view and one basic scan-to-file path). The owner approves it on the phone before any
other Bolt runs.

## Testing Posture

We split testing by what can be tested without the phone. Sensor-independent logic
(geometry, accuracy comparison, export) has automated tests written alongside the code,
with a minimum of 80% line coverage on that logic, run in every build before merge.
Sensor-dependent behaviour cannot run in the build, so each delivery carries a written
on-device checklist that the owner works through on the phone.

## Deployment

Every merge to `main` builds, tests and delivers to TestFlight automatically. There is
one environment, the owner's phone; there is no staging or production split and no
server to deploy.

## Code Style

The language's standard formatter and linter run in every build, and a failure blocks
the merge. Naming follows the language's own conventions. Prose, comments and
user-facing text use Australian English; platform names are left as the platform spells
them.
