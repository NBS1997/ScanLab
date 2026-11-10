# RAID Log — LidarApp

Sources: [intent-statement.md](../intent-capture/intent-statement.md),
[feasibility-assessment.md](feasibility-assessment.md) and
[constraint-register.md](constraint-register.md).

## Risks

| ID | Risk | Likelihood | Impact | Response |
|---|---|---|---|---|
| R1 | Scans of small parts are not accurate enough to design against, so S2 cannot be met for the headline use case. | High | High | Measure first with the reference object (S1). Treat photographs-for-detail plus depth-for-scale as core. Report achievable accuracy by size class so the owner knows what to trust. |
| R2 | Slow trial loop (no Mac) combined with no iPhone development experience makes progress frustrating and faults hard to find. | High | Medium | Small increments; deliver an end-to-end skeleton to the phone early; build diagnostics into the app; check sensor-independent logic automatically in the hosted build. |
| R3 | Multi-camera offset correction absorbs most of the effort for little measurable gain. | Medium | Medium | Do it after single-camera detail is measured; decide on S1 numbers; cap the effort. |
| R4 | The platform's built-in photograph-to-model capability does not behave as assumed on this device, or restricts what the app can control. | Medium | High | Exercise it in an early delivery as part of S3 before relying on it. |
| R5 | Scans are too detailed for Fusion to handle comfortably. | Medium | Medium | Export at a controllable level of detail; test a real scan in Fusion early. |
| R6 | Difficult surfaces (shiny, dark, transparent) on real parts give poor results even when the reference object scans well. | High | Medium | Record as S3 findings; document surface preparation (for example, a matt coating) as a usage technique. |
| R7 | A signing secret or credential is committed to the public repository. | Low | High | Secrets only in the build service's store; ignore rules for key files from the first commit. |
| R8 | The reused build workflow needs changes for this app that are hard to diagnose without a Mac. | Medium | Medium | Make the first delivery an almost-empty app, so pipeline faults are separated from app faults. |
| R9 | The delivered build expires and the app stops opening when it is needed. | Medium | Low | Schedule a periodic rebuild and redelivery. |
| R10 | The hosted build service or its free allowance for public repositories changes. | Low | Medium | No action now; revisit if it happens. |

## Assumptions

| ID | Assumption | How it gets verified |
|---|---|---|
| A1 | The depth sensor resolves features at about a centimetre, over roughly 0.25–5 m. | S1 reference-object scans. |
| A2 | Photographs plus depth give markedly better small-part accuracy than depth alone. | S1, comparing both on the same reference object. |
| A3 | The phone reports the offset and lens characteristics of each camera accurately enough to combine them. | S3 exploration. |
| A4 | More than one rear camera can be used at the same moment, with restrictions. | S3 exploration. |
| A5 | A build-and-deliver round trip takes tens of minutes. | First delivery. |
| A6 | TestFlight builds expire after about 90 days. | Apple's current published rules, checked at first delivery. |
| A7 | The fishing app's build workflow can build this app with configuration changes only. | First delivery (see R8). |
| A8 | Calipers are accurate enough to act as the truth for S1 and S2. | Owner confirms caliper resolution when measuring the reference object. |

## Issues

| ID | Issue | Owner | Status |
|---|---|---|---|
| I1 | The seeded guideline documents in `docs/` still contain unfilled placeholders. | Owner | Open — to be filled as inception decisions are made. |
| I2 | The local checkout of the Nathans Fishing App repository does not contain the build workflow; it exists on GitHub. | Owner | Open — fetch from GitHub when the pipeline is set up. |
| I3 | No licence has been chosen for the public repository. | Owner | Open — decide before the repository is published. |

## Dependencies

| ID | Dependency | Needed for | Status |
|---|---|---|---|
| D1 | Paid Apple developer membership, kept current. | Any delivery to the phone. | In place (Q2). |
| D2 | GitHub's hosted Mac build machines, free for public repositories. | Every build. | Available. |
| D3 | Signing secrets configured in the new repository's secret store. | First delivery. | Not yet done. |
| D4 | The build-and-deliver workflow from the Nathans Fishing App repository. | First delivery. | Exists; not yet copied. |
| D5 | The 3D-printed reference object, measured with calipers. | S1 and S2. | Not yet designed. |
| D6 | The owner's cloud storage, reachable from both the phone and the Windows computer. | Getting scans to the computer. | Assumed available (Q8). |
