# Constraint Register — LidarApp

Sources: [intent-statement.md](../intent-capture/intent-statement.md),
[feasibility-questions.md](feasibility-questions.md) (Q1–Q9) and
[feasibility-assessment.md](feasibility-assessment.md).

"Hard" means the work cannot proceed if it is broken. "Soft" means it can be traded off
with the owner's agreement.

## Technical Constraints

| ID | Constraint | Source | Hard / Soft | Effect |
|---|---|---|---|---|
| TC1 | No Mac. Every build runs on GitHub's hosted Mac machines. | Q1 | Hard | Each trial on the phone is a build-and-deliver round trip; nothing can be watched running from the computer. |
| TC2 | One target device: the owner's iPhone 17 Pro Max. | Intent statement | Hard | No need to support other phones or older system versions; behaviour only has to be right on this device. |
| TC3 | Sensor behaviour can only be checked on the phone. | Assessment | Hard | Anything depending on real depth data needs a delivered build to verify. |
| TC4 | The depth sensor is room-scale and coarse. *(Assumption until S1 is measured.)* | Assessment | Hard | Small-part accuracy cannot come from the depth sensor alone. |
| TC5 | Output must open in Autodesk Fusion, Blender and a 3D-printing slicer. | Q5 | Hard | Common surface-model file types; level of detail must be controllable so Fusion stays usable. |
| TC6 | No third-party app or sign-up service anywhere between scan and usable file. | Intent statement S4 | Hard | Everything from capture to export happens in the app. |
| TC7 | The owner's computer is Windows. | Workspace | Hard | Direct wireless sharing from phone to computer is unavailable; transfer goes through the owner's cloud storage or a cable. |
| TC8 | Test builds delivered through TestFlight stop working after a fixed period. *(Assumption: about 90 days.)* | Platform rule | Hard | The app must be rebuilt and redelivered periodically even when nothing changes. |

## Organisational Constraints

| ID | Constraint | Source | Hard / Soft | Effect |
|---|---|---|---|---|
| OC1 | One person; no prior iPhone development experience; relies on AI-written code. | Q7 | Hard | Work must be explainable and delivered in small, checkable steps. |
| OC2 | No new spending. | Q9 | Hard | Public repository so hosted Mac builds are free; no paid services or libraries. |
| OC3 | No deadline; hobby pace. | Q9 | Soft | Sequence by learning value, not by date. |
| OC4 | Reuse the existing build-and-deliver workflow from the Nathans Fishing App repository. | Q3 | Soft | Avoids re-solving signing and delivery; ties this app to that workflow's conventions. |
| OC5 | The repository is public. | Q4 | Hard | Everything committed is visible to anyone. See RC2. |

## Regulatory and Policy Constraints

| ID | Constraint | Source | Hard / Soft | Effect |
|---|---|---|---|---|
| RC1 | The platform requires the app to state why it uses the camera (and any other protected capability) before it can run. | Platform rule | Hard | A missing statement stops the app from working or being delivered. |
| RC2 | Signing keys, certificates and account credentials must never be committed. | OC5, security | Hard | They live only in the build service's secret store. |
| RC3 | Each delivery through TestFlight asks whether the app uses encryption. | Platform rule | Hard | Answered once in the app's settings so deliveries are not held up. |
| RC4 | A public repository needs a stated licence, and any third-party code used must have a compatible licence. | OC5 | Soft | Choose a licence before publishing; check licences before adding anything. |
| RC5 | Scan data stays on the phone or in the owner's own cloud storage. | Q8 | Hard | No data sent anywhere else. |

No industry regulation (payments, health, privacy of other people's data) applies: the
app has one user and handles only the owner's own scans.
