# Rough Mockups — Clarifying Questions

> Context: [scope-document.md](../scope-definition/scope-document.md) lists 13 in-scope
> capabilities for one user on one phone, and [intent-backlog.md](../scope-definition/intent-backlog.md)
> sequences them risk-first. [intent-statement.md](../intent-capture/intent-statement.md)
> names the capture process as a pain point. The device is fixed (iPhone 17 Pro Max), so
> form factor is not asked. These questions shape the screens and the main flow.

## Q1. What should you see when the app opens?
- A. **The live camera, ready to scan** — the library and other areas are one tap away.
- B. **Your scan library**, with a prominent "new scan" button.
- C. **Tabs along the bottom** — Scan, Library, Explore (hardware), Accuracy — opening on Scan.
- X. Other (please specify)

[Answer]: B

## Q2. How should the hardware exploration views be presented?
- A. **One live view with switchable layers** — camera, depth, confidence, edges — toggled on and off over the same picture.
- B. **A separate screen per capability**, each with its own explanation and readings.
- C. **Both** — layers on the live view, plus a details screen listing what the hardware reports.
- X. Other (please specify)

[Answer]: C

## Q3. During capture your eyes are often on the object, not the screen. How should guidance reach you? (select all that apply)
- A. **On screen** — coverage shown over the live view, with short prompts.
- B. **Haptics** — the phone taps or buzzes when you move too fast or lose tracking.
- C. **Sound** — tones or spoken prompts.
- X. Other (please specify)

[Answer]: B, C — follow-up: coverage is still shown on screen for when the owner glances at it; haptics and sound carry the alerts

## Q4. How will you hold the phone while scanning?
- A. **Portrait** (upright).
- B. **Landscape** (sideways).
- C. **Either** — the app should work both ways.
- X. Other (please specify)

[Answer]: C

## Q5. What should the app look like?
- A. **Standard iPhone look** — familiar controls, follows the phone's light or dark setting.
- B. **Dark, instrument-style** — a technical look suited to studying sensor output, always dark.
- C. **No preference** — whatever is simplest to build well.
- X. Other (please specify)

[Answer]: A

## Q6. Are there accessibility needs beyond the phone's standard settings?
The app will respect the phone's text size, contrast and screen-reader settings regardless.

- A. **No** — the standard settings are enough.
- B. **Yes** (please describe in the answer).
- X. Other (please specify)

[Answer]: A
