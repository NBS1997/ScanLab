# LidarApp — Architecture

> **Unfilled stub.** Seeded 2026-11-10 into an empty repo. The structure below is the
> frame only; nothing here describes real code yet. Fill it in as the app takes shape.

System overview for orientation. For coding rules see `docs/CONVENTIONS.md`; for why
things are this way see `docs/DECISIONS.md`.

**Stack:** ~~primary-language / ~~framework
**Entry point:** `~~entry-point`

## System Layers

Describe the layers and — more importantly — the allowed direction of dependency
between them. The arrows are the part that gets violated.

```
<layer>  →  <layer>  →  <layer>  →  <layer>
```

| Layer | Owns | May depend on | Must not depend on |
|---|---|---|---|
| | | | |

State the boundary rules explicitly. For example: "lower layers never import from
higher ones", "no circular dependencies", "the data layer is the only place that talks
to the database". Rules that aren't written down aren't rules.

## File Structure

```
~~source-dir/
  <dir>/        <one-line description of what lives here>
  <dir>/        <...>
```

Annotate every top-level directory. An unannotated tree is just `ls` output.

## Key Modules

| Module | Responsibility | Notes |
|---|---|---|
| | | |

One row per module that a newcomer would need to know about. Not every file.

## Data Flow

Walk the one or two most important paths end to end — the request that matters, or the
main processing pipeline. Name the actual functions and files at each hop.

```
<entry>  →  <handler>  →  <service>  →  <store>  →  <response>
```

## External Integrations

| Service | Used for | Failure behaviour |
|---|---|---|
| | | |

The failure column matters more than the other two. What happens when it's down?

## Areas of Extra Caution

The parts that are load-bearing, surprising, or expensive to get wrong. Each entry: what
it is, why it's delicate, and what to do before touching it.

- **<area>** — <why it's delicate, and what to check first>

This section is the highest-value part of this document. Fill it in as you learn, and
be specific: "the migration runner is not idempotent, verify against a copy first" is
useful; "be careful with the database" is not.
