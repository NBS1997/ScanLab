# Design System Mapping — LidarApp MVP

Sources: `mockups.md`, `interaction-spec.md`, `requirements.md` (NFR-6),
`wireframes.md`, `user-flow.md`. The app has no design system of its own: it uses the
phone's standard components and settings (rough mockups Q5-A).

## Component Mapping

| App component | Standard iPhone element |
|---|---|
| Library, Hardware details, Diagnostics, Reference object | Grouped list inside a navigation stack with a large title |
| Scan row actions | Swipe actions and context menu |
| New scan method cards | List rows with a disclosure indicator |
| Export, Reference object | Sheet |
| Detail picker, file type | Standard single-choice picker rows |
| Raw-capture switch | Standard toggle |
| Layer chips | Toggle buttons in a bottom toolbar |
| Confirmations | Standard confirmation dialog |
| Save destination | The system's document chooser (FR-7.4) |
| Model view | The system's 3D viewer control |
| Progress | Standard determinate progress bar |
| Haptics | The system's notification and impact feedback styles |

## Visual Tokens

| Token | Value |
|---|---|
| Colours | System semantic colours only (label, secondary label, grouped background, tint, red, green, orange); no custom palette |
| Light and dark | Follows the phone's setting |
| Type | System text styles (large title, headline, body, footnote); monospaced digits for measurements and the log |
| Icons | System symbol set |
| Spacing and corner radius | System list and control defaults |
| Coverage tint | The tint colour at reduced opacity over the camera picture |
| Depth layer | A colour ramp from near (warm) to far (cool); a legend is shown when the layer is on |

## Custom Elements

Only three things are drawn by the app: the capture coverage tint; the depth, confidence
and edge layers; and the accuracy tables. Everything else is standard.
