# CI/CD Pipeline — Bolt 1

Inputs: `unit-of-work.md` (U01, U02), `requirements.md` (FR-1, FR-10, NFR-1–12), `decisions.md` (ADR-001–016), `bolt-plan.md` (Bolt 1), `.claude/rules/aidlc-team.md`.

## `ci.yml` (ours) — on every push and pull request

1. Fail if key material is tracked (`*.p12`, `*.key`, `*.p8`, `*.mobileprovision`).
2. `swiftlint --strict`.
3. `swift format lint --strict --recursive` over the Swift sources.
4. `swift test --enable-code-coverage` in `Packages/ScanLabCore`; fail under 80% line
   coverage (`scripts/check-coverage.sh`).
5. Generate the project with XcodeGen and compile the app for the device without
   signing, so app-target errors surface on every push.

## `ios-build.yml` (builder-managed) — run by `builder ios build` or `builder ios release`

Generates the project, builds Release, signs with the `store` secrets, returns the IPA.
Not edited by hand; `builder update` maintains it.

## Release (from the PC, after each Bolt merges)

`builder ios release --profile store --group <internal group>`: next build number,
upload, wait for processing, add to the TestFlight group.
