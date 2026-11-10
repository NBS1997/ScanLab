# Application Design — Stage Memory

## Interpretations

- 2026-11-10T10:50:00Z — Service communication, cloud service mapping and scaling questions do not apply: single on-device app, no server. The cloud-platform perspective is recorded as "not applicable" in decisions.
- 2026-11-10T10:50:00Z — Only choices that turn on the owner preference, cost rule or tools were asked; internal structure is decided by the architect and recorded as ADRs, since the owner has no iPhone development experience.

## Deviations

- 2026-11-10T10:50:00Z — Interaction-mode question not asked (see user-stories memory).

## Tradeoffs

- 2026-11-10T11:05:00Z — Own implementations of mesh simplification, alignment and fitting were chosen over libraries (ADR-008, ADR-013); the cost is more code, accepted because it is all testable in the build.
- 2026-11-10T11:05:00Z — Log retention set to 5,000 lines (requirement asks for at least 1,000).

## Open questions

- 2026-11-10T11:05:00Z — The fishing app's build workflow has only been skimmed (step names); that it builds a native XcodeGen project with configuration changes alone is unverified until the first delivery (RAID A7).
- 2026-11-10T11:05:00Z — Framework API details in the ADRs (Object Capture output as OBJ, Vision contours, ARKit tracking states) are from documentation, not from compiling; code generation must confirm them.
- 2026-11-10T11:05:00Z — Accuracy reliability thresholds (2 mm residual, 60% coverage) are provisional.
