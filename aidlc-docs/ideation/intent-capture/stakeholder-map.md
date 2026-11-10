# Stakeholder Map — LidarApp

Source: [intent-statement.md](intent-statement.md) and
[intent-capture-questions.md](intent-capture-questions.md) (Q7).

## Key Stakeholders

| Stakeholder | Role | Interest |
|---|---|---|
| The owner | Sponsor, sole user, product decision-maker, tester | A trustworthy 3D model of real parts; first-hand understanding of the hardware; no dependence on third-party apps or sign-up services. |
| Apple (platform) | Gatekeeper, external | Controls what the hardware exposes to apps, and the rules for building, signing and distributing an app through TestFlight. Has no interest in this app but can constrain it. |
| GitHub (build service) | Supplier, external | Hosts the code and runs the builds that produce the app. A service limit or outage delays delivery; it has no say in what is built. |

This is a single-person initiative (Q7: "just me"). There are no other users, testers,
funders or approvers.

## Decision-Makers and Influencers

| Decision | Decided by | Influenced by |
|---|---|---|
| What the app does and in what order | The owner | Findings from the reference-object measurements; what the hardware turns out to support |
| Whether a result is good enough | The owner | Success metrics S1–S4 in the intent statement |
| What can be built and distributed at all | Apple's platform rules | — |

The owner approves every stage gate in this workflow. No second approver exists, so there
is no sign-off chain to manage.

## Communication Requirements

- **Stage gates** are the only formal communication: each stage ends with a summary and an
  approve or request-changes decision by the owner.
- **Artefacts** live in `aidlc-docs/` in the repository, so the record of what was decided
  and why stays with the code.
- **No external reporting.** No status updates, stakeholder briefings or release notes for
  an audience are required.
- **Platform changes** (Apple's distribution rules or hardware access) are checked when a
  stage depends on them, not monitored continuously.
