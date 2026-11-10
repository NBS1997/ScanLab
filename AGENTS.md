# LidarApp

Shared instructions for every coding agent on this repo. Don't add a `CLAUDE.md` or
`CLAUDE.local.md` anywhere: Claude Code reads those instead and silently ignores this file.

~~primary-language project using ~~framework. ~~package-manager for dependencies,
minimum runtime ~~min-runtime-version. Source lives in `~~source-dir`.

## Commands

```bash
~~test-command      # run the test suite
~~lint-command      # lint and format check
~~build-command     # build
```

## Critical Rules

The mistakes that actually cost time here. Keep this list short — five to ten entries.
If it grows past that, the extras belong in `docs/CONVENTIONS.md`.

1. **Australian English** — colour, favourite, centre, behaviour, organise. Never
   American spelling, in code or prose.
2. **Read before you change** — check `docs/DECISIONS.md` before refactoring anything
   that looks suboptimal. It may be deliberate.
3. **Every bug fix gets a regression test** that fails without the fix.
4. *(Add rules as you discover them. Each one line. Each one earned by a real failure.)*

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
- Run `~~test-command` after changes. A change with a failing suite isn't finished.
- When you make a decision worth remembering, record it as an ADR in
  `docs/DECISIONS.md` while it's still fresh.
- When a documented rule gets in your way, add a row to the Friction Log in
  `docs/ANTI_PATTERNS.md` rather than quietly working around it.
