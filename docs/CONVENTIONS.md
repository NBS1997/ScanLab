# LidarApp — Conventions

> **Unfilled stub.** Seeded 2026-11-10 into an empty repo. The structure below is the
> frame only; nothing here describes real code yet. Fill it in as the app takes shape.

Single source of truth for how code is written here. Every change is reviewed against
this document.

## Language & Spelling

- **Australian English** throughout — colour, favourite, centre, behaviour, organise,
  licence (noun) / license (verb). Applies to identifiers, comments, commit messages,
  UI strings and documentation.
- Prose in documentation is plain and direct. No filler.

## Types & Naming

| Thing | Convention | Example |
|---|---|---|
| Files | | |
| Types / classes | | |
| Functions | | |
| Constants | | |
| Test files | | |

State the rule for the escape hatch too — when is an untyped value acceptable, and what
must accompany it (usually a comment explaining why).

## File Size Limits

Limits force extraction, which is the point. Pick numbers that fit the language and
enforce them.

| Kind | Limit | When exceeded |
|---|---|---|
| Source file | ~~lines | Extract to <the project's extraction pattern> |
| Function | ~~lines | Extract helpers |

Note any exempt file kinds (generated code, type definitions, static data) explicitly,
otherwise the limit gets argued about every time.

## Import Order

Group imports, separated by blank lines, in a fixed order. State it, and let the linter
enforce it:

```
1. Standard library
2. Third-party dependencies
3. Internal modules (absolute)
4. Local modules (relative)
5. Types
```

## Error Handling

Document the project's single error-handling pattern and stick to it. Cover:

- The return or raise convention for fallible operations.
- Which layer converts internal errors into user-facing ones.
- What must never be swallowed silently.
- How errors are logged — the logging call shape, and what must never appear in a log.

Mixed error-handling styles in one codebase are a reliable source of dropped failures.
Pick one, write it here, and note the exceptions if any exist.

## Code Patterns

For each recurring pattern, point at a real file that demonstrates it. A pointer to
working code ages better than a snippet in a document.

| Pattern | Reference implementation |
|---|---|
| | `~~source-dir/...` |

## Testing

Summarised here, detailed in `docs/TESTING.md`:

- Every new public function gets a test.
- Every bug fix gets a regression test that fails without the fix.

## Git Conventions

- **Branches:** `<type>/<short-description>` — branch from `main`, never
  commit to it directly.
- **Commits:** <format>. Imperative mood, present tense.
- **Pull requests:** title format, and what the description must contain.

## Architecture Boundaries

The import rules from `docs/ARCHITECTURE.md`, restated as things a reviewer checks:

| Layer | May import | Must not import |
|---|---|---|
| | | |

## Before Submitting

- [ ] `~~lint-command` passes
- [ ] Tests pass, and new behaviour has new tests
- [ ] No debug logging left in
- [ ] Docs updated if the change alters a documented interface or decision
