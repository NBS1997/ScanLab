# LidarApp

Shared instructions for every coding agent on this repo. Don't add a `CLAUDE.md` or
`CLAUDE.local.md` anywhere: Claude Code reads those instead and silently ignores this file.

The app is **ScanLab** (GitHub `NBS1997/ScanLab`, bundle ID `com.nbs1997.scanlab`).
Swift 6 project using SwiftUI. Swift Package Manager for the Core package; no
third-party code ships in the app (ADR-008). Minimum iOS 26.0, built with Xcode 26.
Source lives in `App/Sources` (app, adapters, screens) and
`Packages/ScanLabCore/Sources` (sensor-independent logic). The Xcode project is
generated from `project.yml` by XcodeGen.

## Commands

There is no Mac and no local Swift toolchain: these run on GitHub's macOS runners
(`.github/workflows/ci.yml`) on every push.

```bash
swift test --package-path Packages/ScanLabCore --enable-code-coverage   # Core tests
scripts/check-coverage.sh 80                                             # coverage floor
swiftlint lint --strict && swift format lint --strict --recursive App/Sources Packages/ScanLabCore
xcodegen generate && xcodebuild -scheme ScanLab -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
builder ios release --profile store    # from the Windows PC: signed build, upload, TestFlight
```

## Critical Rules

The mistakes that actually cost time here. Keep this list short — five to ten entries.
If it grows past that, the extras belong in `docs/CONVENTIONS.md`.

1. **Australian English** — colour, favourite, centre, behaviour, organise. Never
   American spelling, in code or prose.
2. **Read before you change** — check `docs/DECISIONS.md` before refactoring anything
   that looks suboptimal. It may be deliberate.
3. **Every bug fix gets a regression test** that fails without the fix.
4. **Core never imports sensor or UI frameworks** — only Foundation. Sensor code lives in
   App adapters behind Core's ports (ADR-003).
5. **No console output** — log through the `Logging` port so it reaches the on-phone
   diagnostics log (ADR-011; enforced by SwiftLint).
6. **Never commit signing material** — key files live in `C:\Users\natys\.scanlab-signing`;
   `.github/workflows/ios-build.yml` is managed by `builder`, not edited by hand.

## Documentation Map

| When you need... | Read |
|---|---|
| How the system fits together | `docs/ARCHITECTURE.md` |
| How to write code that belongs here | `docs/CONVENTIONS.md` |
| Why something is the way it is | `docs/DECISIONS.md` |
| What looks right but is wrong here | `docs/ANTI_PATTERNS.md` |
| What will block a review | `docs/SECURITY.md` |
| What to test and how to run it | `docs/TESTING.md` |

## AI-DLC Workflow

This project uses AI-DLC (AI-Driven Development Life Cycle), framework version 0.4.7,
copied from `ewd-driver-app` on 2026-11-10. Requires `bun` on the PATH.

- Run `/aidlc <description>` to start or resume a workflow; `/aidlc --status`,
  `--doctor`, `--init`, `--stage <slug>` and `--phase <name>` are also available.
- On startup, check for `aidlc-docs/aidlc-state.md`. If found, load prior context and
  offer to resume from the last checkpoint.
- All AI-DLC artefacts go to `aidlc-docs/`. Application code goes to the workspace root.
- The framework lives in `.claude/` (`skills/aidlc/`, `agents/`, `rules/`, `sensors/`,
  `knowledge/`, `tools/`, `hooks/`), with every file prefixed `aidlc-`. The orchestrator
  is `.claude/skills/aidlc/SKILL.md`.
- `.claude/rules/aidlc-*.md` holds AI-DLC process rules only. Code guidelines stay in
  `docs/`; don't duplicate them into `.claude/rules/`.
- Validate Mermaid syntax before writing a diagram, and include a text fallback.

## Working Agreements

- Default branch is `main`. Branch before committing; don't commit to it
  directly.
- Push and check the CI run after changes. A change with a failing run isn't finished.
- When you make a decision worth remembering, record it as an ADR in
  `docs/DECISIONS.md` while it's still fresh.
- When a documented rule gets in your way, add a row to the Friction Log in
  `docs/ANTI_PATTERNS.md` rather than quietly working around it.
