# LidarApp — Testing Strategy

> **Unfilled stub.** Seeded 2026-11-10 into an empty repo. The structure below is the
> frame only; nothing here describes real code yet. Fill it in as the app takes shape.

## Tiers

| Tier | Covers | Lives in | Run with |
|---|---|---|---|
| Unit | Logic — pure functions, services, utilities | | `~~test-command` |
| | | | |

Add a row per tier actually in use. Don't document a tier that doesn't exist yet.

## When Tests Are Required

The rules that matter. These are checked in review:

- **Every new public function** gets a test covering its contract.
- **Every bug fix** gets a regression test that fails without the fix. Write the test
  first, watch it fail, then fix. A regression test that never failed proves nothing.
- **Every refactor** is preceded by a characterisation test if none exists, so the
  refactor can be shown not to change behaviour.

## Test Quality

- Test **behaviour** — inputs to outputs. Not implementation details.
- Mock at external boundaries only: network, filesystem, clock, database, device APIs.
  Mocking internal call order couples the test to the code's shape and makes every
  refactor look like a break.
- Don't assert that a function was called. Assert the observable outcome.
- Name tests as sentences describing the expected behaviour, not the function under
  test: `returns an error when the weight is negative`.

## Conventions

- **Location:** test files mirror the source tree.
- **Naming:** <the project's test file naming pattern>
- **Fixtures:** where shared setup lives, and what must not be shared between tests.
- **Isolation:** each test sets up and tears down its own state. Tests that pass only
  in a particular order are broken tests.

## Running

```bash
~~test-command                    # full suite
~~test-command <path>             # a single file
```

## If a test fails

Fix the implementation, not the test. If a test is genuinely wrong, explain why before
changing it — "the test was wrong" is the most common cover story for a real bug.
