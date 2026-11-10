# LidarApp — Anti-Patterns & Friction Log

Two purposes: document patterns that look correct but fail in this codebase, and give
contributors somewhere to record when a rule caused friction.

---

## Known Anti-Patterns

_No patterns have been recorded yet. The repo held no source when this file was seeded
(2026-11-10). Add AP-001 when a pattern meets the bar in the comment below, using this
format:_

```markdown
### AP-001: <short name of the wrong thing>

**Wrong:** `<the code you would naturally write>`
**Right:** `<what to write instead>`
**Why:** <the concrete failure this causes>
**Detection:** <how a reviewer or a grep finds this>
```

---

<!--
Bar for a new entry: it has caused a real failure, OR a cheap check found it in two or
more places. A single occurrence is an incident — fix the file, don't write a rule.

If a pattern is mechanically detectable, say so in Detection and consider a hook.
Deterministic checks belong in a script, not in a document someone has to remember
to read.
-->

## Friction Log

When a documented rule got in the way, add a row. Log it even when the rule turned out
to be right — that's useful evidence next time someone proposes relaxing it.

| Date | Rule | Friction | Outcome |
|---|---|---|---|
| | | | |

Three entries against the same rule means the rule is probably wrong. Say so rather
than adding a fourth.
