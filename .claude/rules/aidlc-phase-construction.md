# Construction Phase Guardrails

These rules apply to every stage whose `phase: construction` declaration
imports them as the matching phase rule.

## Code Completeness

- Generate complete, runnable files — no partial implementations, no placeholder stubs unless explicitly marked TODO with a rationale
- Every generated module must be independently executable or clearly document its dependencies
- Do not leave unresolved import errors, missing type definitions, or broken references

## Error Handling

- Always include error handling at integration boundaries (API calls, database operations, file I/O, external services)
- Errors must be surfaced to the caller or logged — silent failures are not acceptable
- Distinguish between recoverable errors (retry/fallback) and fatal errors (fail fast)

## Testing Standards

- Test files must cover the happy path and at least two error/edge cases
- Tests must be runnable without manual setup beyond documented prerequisites
- Do not generate tests that always pass regardless of implementation (e.g., `assert True`)

## Security

- Never hardcode credentials, API keys, or secrets — use environment variables or a secrets manager
- Validate and sanitize all inputs at system boundaries
- Flag any code that bypasses authentication or authorization checks

## Corrections

- When units or app-halves are built in parallel against a shared contract, ALWAYS run a REAL cross-component end-to-end integration test (actual services, not mocks of either side) before the Bolt gate. Shared TYPES do not capture runtime contract details — URL scheme, issued-vs-derived identifiers (e.g. `origin`), header semantics, encryption-detection — and such divergences pass isolated unit tests but break the spine. (learnt 2026-06-27; 4 such bugs caught only by the walking-skeleton e2e test)
