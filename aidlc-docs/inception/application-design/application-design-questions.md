# Application Design — Design Plan and Questions

> Inputs: `requirements.md` (FR-1 to FR-10, NFR-1 to NFR-12, PC1–PC5), `stories.md`
> (US-01 to US-14), `platform-verification.md` and `team-practices.md`. There is no
> existing architecture to fit into (greenfield).
>
> Design plan: a single iPhone app in the platform's native language and interface
> toolkit, with no server. The architect will decide component boundaries, internal
> communication and storage, and record each as a decision. The questions below are the
> choices where the owner's preference, cost rule or tools change the answer.

## Q1. Which build tools and minimum system version?
The phone runs iOS 27. The hosted build service's stable tools target iOS 26; its iOS 27 tools are a public preview.

- A. **Stable tools, minimum iOS 26** — builds with the stable toolset; the app runs on the phone's iOS 27 but cannot use features new in iOS 27.
- B. **Preview iOS 27 tools** — can use iOS 27 features; depends on a preview build image that may change or break.
- C. **Start on stable, move to iOS 27 tools when they leave preview.**
- X. Other (please specify)

[Answer]: C

## Q2. May the app use free open-source libraries?
The no-cost rule forbids paid dependencies. Some needed pieces (simplifying a mesh, matching a scan to a known shape) are not provided by the platform.

- A. **Platform frameworks only** — write the missing pieces ourselves, with tests. More code to own; nothing external to trust or keep updated.
- B. **Free, well-established open-source libraries allowed** where they save significant work, with the licence recorded first.
- C. **Decide case by case**, defaulting to platform-only.
- X. Other (please specify)

[Answer]: C

## Q3. How should the accuracy report measure a scan?
The requirement is automatic comparison with per-feature figures.

- A. **Surface deviation only** — line the scan up with the known shape and report how far the scanned surface sits from it, per feature region. Robust and simpler, but gives "surface is 0.6 mm off here", not "this hole measures 9.1 mm".
- B. **Feature fitting only** — find each face, hole and step in the scan and compute its dimension, to compare with your caliper value. Matches the report in the mockups; more complex and more fragile on rough scans.
- C. **Both, staged** — surface deviation first (earlier answer to "how accurate is it?"), feature fitting added after.
- X. Other (please specify)

[Answer]: C

## Q4. How should the reference object be authored?
The app needs the object's exact shape and a table of its features; you need a printable file and an editable design.

- A. **From a script** — a free, text-based modelling tool generates the printable file, the feature table and an exchange file Fusion can open, all from one source, so they cannot drift apart.
- B. **In Fusion** — designed directly in Autodesk Fusion (which you already use), exported for printing; the feature table is maintained alongside by hand.
- X. Other (please specify)

[Answer]: A

## Q5. What should the app be called on the phone?
- A. **LidarApp** — matches the repository.
- B. **ScanLab**
- C. **DepthBench**
- X. Other (please specify)

[Answer]: B

## Q6. Which licence should the public repository carry?
- A. **MIT** — anyone may use the code with attribution; simplest and most common.
- B. **Apache 2.0** — similar, with an explicit patent grant.
- C. **No licence** — the code is visible but others have no right to reuse it.
- X. Other (please specify)

[Answer]: A
