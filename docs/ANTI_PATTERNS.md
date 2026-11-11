# LidarApp — Anti-Patterns & Friction Log

Two purposes: document patterns that look correct but fail in this codebase, and give
contributors somewhere to record when a rule caused friction.

---

## Known Anti-Patterns

### AP-001: Passing `url.path()` to FileManager

**Wrong:** `FileManager.default.fileExists(atPath: folder.path())`
**Right:** `FileManager.default.fileExists(atPath: folder.fileSystemPath)`
**Why:** `path()` percent-encodes the result, so "Application Support" becomes
"Application%20Support" and every check looks in a folder that does not exist. In build
4 a saved sweep opened as "This scan could not be found" (ADR-021).
**Detection:** SwiftLint custom rule `no_escaped_file_path` (regex `\.path\(\)`) fails
CI. Regression tests use a real folder named "Application Support".

### AP-002: Letting zero-cost merges pile into one vertex

**Wrong:** a quadric simplifier that breaks equal-cost ties by vertex number, with no
limit on how many neighbours a merged vertex may have.
**Right:** keep `EdgeCollapser.lengthWeight` (short edges first) and
`EdgeCollapser.maximumValence` (24).
**Why:** on flat areas every merge costs nothing, so merges built "hub" vertices with
hundreds of neighbours; the simplifier went quadratic and the 79,360-face test exceeded
its CI time limit (ADR-026).
**Detection:** `SimplifierTests` — "no vertex ends up joined to too many others" and the
time-limited large-mesh test.

### AP-003: Case-sensitive assumptions in `.gitignore`

**Wrong:** `build/` in `.gitignore`.
**Right:** anchor build-output patterns to the root: `/build/`.
**Why:** the owner works on Windows, where paths are case-insensitive, so `build/`
matched Core's `Sources/ScanLabCore/Build/` source folder (found in CI during Bolt 1).
**Detection:** review any new ignore pattern against folder names in `Packages/` and
`App/`; `git check-ignore -v <path>` shows which pattern matches.

### AP-004: Long one-line arithmetic expressions in Swift

**Wrong:** building a cube's corners or a matrix in one long expression of literals and
operators.
**Right:** split into named intermediate values or a loop.
**Why:** the Swift type checker timed out on a one-line cube-corner expression in a test
helper (Bolt 3), failing CI. With no local compiler, each such failure costs a full CI
round trip.
**Detection:** CI error "the compiler is unable to type-check this expression in
reasonable time".

---

<!--
Bar for a new entry: it has caused a real failure, OR a cheap check found it in two or
more places. A single occurrence is an incident — fix the file, don't write a rule.

If a pattern is mechanically detectable, say so in Detection and consider a hook.
Deterministic checks belong in a script, not in a document someone has to remember
to read.

Format:

### AP-0NN: <short name of the wrong thing>

**Wrong:** `<the code you would naturally write>`
**Right:** `<what to write instead>`
**Why:** <the concrete failure this causes>
**Detection:** <how a reviewer or a grep finds this>
-->

## Friction Log

When a documented rule got in the way, add a row. Log it even when the rule turned out
to be right — that's useful evidence next time someone proposes relaxing it.

| Date | Rule | Friction | Outcome |
|---|---|---|---|
| | | | |

Three entries against the same rule means the rule is probably wrong. Say so rather
than adding a fourth.
