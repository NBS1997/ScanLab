# Code Generation Plan — Bolt 1 (U01 Delivery Skeleton, U02 Diagnostics Log)

Inputs: the U01 and U02 design records in `aidlc-docs/construction/`, `bolt-plan.md`
(Bolt 1), `decisions.md` (ADR-001 to ADR-016), `stories.md` (US-01, US-02).

## Steps

| # | Step | Output | Status |
|---|---|---|---|
| 1 | Create the public repository NBS1997/ScanLab and push `main` | Remote `origin` | Done |
| 2 | `builder init`; set bundle ID; remove the unused share workflow | `builder.json`, `.github/workflows/ios-build.yml` | Done |
| 3 | `builder signing setup --distribution store`, key material outside the repository | Bundle ID, certificate, profile, four repository secrets | Done |
| 4 | Core package: log model, codec, trimmer, formatter, Logging port, memory log, build info | `Packages/ScanLabCore/Sources` | Done |
| 5 | Core tests (Swift Testing) | `Packages/ScanLabCore/Tests` (26 tests) | Done |
| 6 | App: composition root, file log adapter, Library and Diagnostics screens | `App/Sources` | Done |
| 7 | Project manifest with build-date stamp, Info.plist properties, icon | `project.yml`, `App/Resources` | Done |
| 8 | Lint, format, coverage gate, CI workflow | `.swiftlint.yml`, `.swift-format`, `scripts/check-coverage.sh`, `.github/workflows/ci.yml` | Done |
| 9 | Licence, README, `AGENTS.md` placeholders filled, `.gitignore` and `.gitattributes` | Repository root | Done |
| 10 | CI green on GitHub | Run 42807111212 | Done |
| 11 | Signed build delivered to TestFlight group "Owner" | `builder ios release` | In progress |
| 12 | On-device checklist for the owner | `docs/checklists/bolt-01-walking-skeleton.md` | Done |
