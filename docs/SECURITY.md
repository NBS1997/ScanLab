# LidarApp — Security Rules

> **Unfilled stub.** Seeded 2026-11-10 into an empty repo. The structure below is the
> frame only; nothing here describes real code yet. Fill it in as the app takes shape.

These are non-negotiable. Violations block a review regardless of context.

## Input Validation

- Validate all external input at the boundary, before it reaches business logic.
- State where validation lives and which function owns it, so it isn't reimplemented
  ad hoc at each call site.
- Range checks, length caps and required-field checks are defined once and reused.

## Injection Safety

- Never build a query by string concatenation or interpolation. Use parameterised
  queries or the ORM's binding API, always.
- Where a dynamic identifier (table, column, sort field) is genuinely needed, validate
  it against an allowlist. Never pass user input through as an identifier.
- The same rule applies to shell commands, file paths and template rendering.

## Secrets

- Never hardcode keys, tokens, passwords or connection strings. Configuration comes
  from the environment or a secrets manager.
- Never log a secret, at any level, including debug.
- Document where credentials actually live so nobody invents a second mechanism.

## Sensitive Data

- Name what counts as sensitive in this project — credentials, personal information,
  location, financial data, health data.
- State what must never be logged, and what must be redacted or stripped before any
  data leaves the system.

## Dependencies

- Run the audit command after any dependency change (`~~package-manager audit` or the
  ecosystem equivalent).
- If a CVE has no upstream fix, pin to the last safe version and record why here, with
  the date and the CVE reference. Pins without a recorded reason get "helpfully"
  upgraded later.
- Check licence compatibility before adding any new dependency. Copyleft licences on a
  distributed product are a legal problem, not a preference.

### Pinned for security

| Package | Pinned to | Reason | Date |
|---|---|---|---|
| | | | |
