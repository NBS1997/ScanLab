# Risk and Sequencing Rationale — ScanLab (LidarApp)

Inputs: `bolt-plan.md`, `unit-of-work-dependency.md`, `requirements.md`, `stories.md`,
the feasibility RAID log, `decisions.md`, and `.claude/rules/aidlc-team.md`.

## Heuristic

**Walking-skeleton-first, then risk-first** (Cockburn's walking skeleton; Cohn's
risk-first ordering of uncertain work). WSJF scoring was not used: there is one owner,
one value stream and no deadline, so "value" and "time criticality" do not
differentiate Bolts; risk reduction does.

Chosen because:
- The owner asked for a gated skeleton (team practices) and a thin first version (scope
  Q1-C).
- The scope was sequenced risk-first by the owner (scope Q4-A), because one unknown,
  small-part accuracy, could undermine the whole idea.

## The Risks, and Where Each Is Retired

| Risk | Retired by | Step |
|---|---|---|
| R8 Reused build workflow does not work for this app | Bolt 1 | 1 |
| R2 Slow loop, faults hard to find without a Mac | Bolt 1 (diagnostics log in the skeleton) | 1 |
| R5 Scans too detailed for Fusion | Bolt 3, with a sample mesh before any capture | 2 |
| Reference object lead time (print and measure) | Bolt 2, started early | 2 |
| NFR-8 Scans lost on crash or update | Bolt 5 | 3 |
| R4 Platform photo capability behaves differently | Bolt 7 | 4 |
| R1 Small-part accuracy falls short | Bolts 7 and 8 together | 4 |
| RA3 Alignment error swamps scan error | Bolt 8 | 4 |
| Feature fitting fragile on real scans | Bolt 9 | 5 |
| Capture stays frustrating | Bolt 10 | 5 |

By the end of step 4, every high-impact risk in the RAID log has been tested on the
phone. Steps 5 and 6 improve a path already known to work or not.

## Why Bolt 1 Bundles Two Units

The diagnostics log (U02) is the only way to see what the app did on a phone that cannot
be attached to a debugger. A skeleton without it would prove delivery but leave every
later fault opaque. U02 is small (S), so bundling it keeps the skeleton thin.

## Deviations from Topological Order

The DAG's layering would put **U13 Hardware details** in layer 3, alongside U05. It is
sequenced last instead.
- **Why:** it is low risk (it only reads and displays values) and its value is the
  written findings record, which is more useful once captures and edges have been
  tried. Its runtime discovery of formats is not needed by U07 or U08, which use the
  platform's defaults.
- **Cost:** the phone's reported capabilities are not on screen until step 6. Live view
  (Bolt 4) and the platform verification already give an early picture. The owner
  considered moving it earlier (Q1-B) and kept it last.

All other Bolts follow the DAG's layers, with parallel batches inside layers.

## Why Accuracy Stage 1 Runs Alongside the Captures

Bolt 8 is pure Core logic proven on synthetic scans, so it does not need Bolts 6 and 7 to
be finished to be built, only to be tried on the phone. Running it in the same batch
means the first real accuracy numbers arrive as soon as both capture methods exist,
which is the point of risk-first sequencing.

## Decision Point

After step 4 the summary reports accuracy for both methods and recommends a direction.
The owner chose not to force a stop there (Q2-B). If Construction is running without
gates, a poor result will still be visible in the summary and the diagnostics, and any
Bolt failure halts and asks regardless of gate mode.
