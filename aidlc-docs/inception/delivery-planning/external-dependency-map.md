# External Dependency Map — ScanLab (LidarApp)

Inputs: `bolt-plan.md`, the feasibility dependencies (D1–D6) and issues (I2, I3),
`decisions.md` (ADR-014, ADR-015) and `delivery-planning-questions.md` (Q3-A).

Everything except these items is contained within the agent's work.

| # | Item | Owner | Lead time | Blocks | Mitigation |
|---|---|---|---|---|---|
| X1 | Public GitHub repository created and the branch pushed | Agent, via the GitHub command-line tool, after the owner confirms the name | Minutes | Bolt 1 delivery | Owner creates it by hand if the tool lacks permission |
| X2 | Signing secrets added to the new repository (certificate, provisioning profile, App Store Connect API key, as the reused workflow expects) | **Owner** — secrets in the fishing app's repository cannot be read back, so they are re-added from their original sources | An hour, if the originals are to hand | Bolt 1 delivery | The workflow's unsigned build path proves compilation while secrets are pending |
| X3 | App record and bundle identifier for ScanLab in App Store Connect | Owner (or the workflow, if it creates identifiers) | Minutes | Bolt 1 delivery | — |
| X4 | Build workflow copied from the Nathans Fishing App repository on GitHub | Agent | Minutes | Bolt 1 | Local checkout lacks it (I2); fetch from GitHub |
| X5 | Hosted Mac runners (`macos-26`), free for public repositories | GitHub | — | Every Bolt | None needed; revisit if pricing changes (R10) |
| X6 | Apple developer membership kept current | Owner | — | Every delivery | — |
| X7 | CadQuery installed where the reference script runs | Agent (build job) or owner (Windows) | Minutes | Bolt 2 | Run it in a build job if not installed locally |
| X8 | Reference object printed and measured with calipers | **Owner** | A print run plus measuring, roughly a day | Bolt 8's on-phone check | Bolt 8's synthetic tests do not need it; only the real check waits |
| X9 | iOS 27 build tools leaving preview | Apple / GitHub | Unknown | Nothing now (ADR-002) | Stay on the stable tools |

## Owner Actions Before Construction Starts

1. Confirm the repository name when asked (X1).
2. Have the signing material ready to add as secrets (X2, X3).
