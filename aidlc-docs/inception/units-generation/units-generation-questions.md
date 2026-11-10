# Units Generation — Decomposition Plan and Questions

> Inputs: the Application Design artefacts (`components.md`, `component-methods.md`,
> `services.md`, `component-dependency.md`, `decisions.md`), `requirements.md` and
> `stories.md`. A Unit is a piece of work built and delivered together.
>
> Already decided, so not asked: the deployment model is a single app delivered whole
> (ADR-001, ADR-014), with the reference-object script and the build workflow as the only
> things outside it. Units integrate through the Core ports defined in Application
> Design. Order of work is a Delivery Planning decision and is not asked here.

## Q1. How should Unit boundaries be drawn?
- A. **By feature slice** — each Unit cuts through screen, logic and adapter for one capability, so every Unit ends in something you can try on the phone.
- B. **By layer** — Core logic Units, adapter Units and screen Units. Cleaner technically; many Units deliver nothing visible on their own.
- C. **By user story** — exactly one Unit per story (14 Units).
- X. Other (please specify)

[Answer]: A

## Q2. How fine should Units be?
- A. **About 13 Units** — each small enough for one build-and-try round, with capture, guidance and the two accuracy stages kept separate.
- B. **About 6 Units** — foundation, explore, capture, library and export, accuracy, hardware findings. Fewer gates; each Unit is large and a fault is harder to locate.
- X. Other (please specify)

[Answer]: A

## Q3. May independent Units be built in parallel?
- A. **Yes, where the dependency graph allows** — Units that do not depend on each other may be built at the same time.
- B. **No, strictly one at a time.**
- X. Other (please specify)

[Answer]: A
