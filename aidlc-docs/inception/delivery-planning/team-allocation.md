# Team Allocation — ScanLab (LidarApp)

Inputs: `bolt-plan.md`, `unit-of-work.md`, `.claude/rules/aidlc-team.md`. Team
Formation did not run (out of `mvp` scope).

## Allocation

All twelve Bolts are executed by the **developer agent** (AI). There is one team, so no
program board is needed.

| Role | Who | Responsibilities |
|---|---|---|
| Build | Developer agent | Code, tests, workflow changes, on-device checklists, plain-language explanations |
| Review | Guideline reviewer agent | Reviews each Bolt's diff against `docs/` before merge |
| Record | Guideline scribe agent | Copies decisions and anti-patterns into `docs/` |
| Approve and verify | The owner | Approves gates; runs each on-device checklist; prints and measures the reference object; adds signing secrets |

## Owner's Hands-On Tasks by Bolt

The owner is the only one who can touch the phone, the printer and the account secrets.

| Bolt | Owner task |
|---|---|
| 1 | Confirm the repository name; add signing secrets; install from TestFlight; run the checklist |
| 2 | Print the reference object; measure it with calipers using the sheet |
| 3 | Export the sample, open it in Fusion, convert to a solid |
| 4 | Measure a wall distance and record the reading |
| 5 | Install a newer build and confirm scans survive |
| 6, 7 | Capture real subjects; open results in Fusion |
| 8 | Enter caliper values; scan the reference object with both methods |
| 9–12 | Run each checklist |

## Parallel Batches

Parallel Bolts are separate agent tasks in separate worktrees, merged in batch order.
The owner's checklists for a batch can be run on one delivered build containing all of
the batch's merges.
