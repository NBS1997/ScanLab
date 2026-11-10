# Accessibility Checklist — LidarApp MVP

Sources: `requirements.md` (NFR-6, FR-5.3), `mockups.md`, `interaction-spec.md`,
`wireframes.md`, `user-flow.md`, `stories.md`. The owner reported no needs beyond the
phone's standard settings (rough mockups Q6-A); the app honours those settings in full.
Checked on the phone at each delivery that changes a screen.

## Checklist

| # | Check | Applies to | How to check |
|---|---|---|---|
| A1 | Every control has a screen-reader label describing its action | All screens | Turn on the screen reader; swipe through each screen |
| A2 | Screen-reader focus lands on the screen title first | All but Capture and Explore live | Open each screen with the screen reader on |
| A3 | Headings are marked: title as level 1, group titles as level 2 | List and report screens | Navigate by headings |
| A4 | No text is cut off or overlapped at the largest standard text size | All screens | Set the largest text size; view each screen |
| A5 | Text and controls meet the system contrast in light, dark and increased-contrast settings | All screens | Switch each setting; view each screen |
| A6 | Colour is never the only signal: errors have text, the accuracy tick has a label, poor figures are marked in words | Library, Export, Accuracy, Diagnostics | Inspect with a greyscale filter |
| A7 | Capture alerts are spoken when the screen reader is on, and are also haptic | Capture | Cover the camera during a capture |
| A8 | The depth layer has a legend; readings are available as text | Explore live | Turn on Depth |
| A9 | The model view has a text description (size, face count) | Scan detail | Focus the model with the screen reader |
| A10 | Tables expose row and column headers | Accuracy report | Read a cell with the screen reader |
| A11 | Touch targets are at least the system minimum size | All screens | Inspect chips, row actions and the Finish button |
| A12 | Every screen works upright and sideways | All screens | Rotate on each screen, including mid-capture |
| A13 | The reduced-motion setting is honoured; nothing flashes | Capture, Explore | Turn on reduced motion |
| A14 | Tones respect the silent switch; no information is carried by sound alone | Capture | Capture with the phone silenced |

## Known Limitation

Capture and live exploration are visual by nature. A7 and A14 ensure alerts are neither
sound-only nor sight-only, but judging a scan's coverage still needs sight.
