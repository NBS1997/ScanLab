# Bolt 1 (Walking Skeleton) — Construction Questions

Stages 3.1–3.4 for U01 and U02 raised no new design questions: Inception settled them.
Four decisions were needed at Bolt start, because the build tooling turned out to differ
from what Application Design assumed (see ADR-016). The owner answered them on 2026-11-10.

## Q1. How should builds reach TestFlight?
- A. **builder after each merge** — GitHub runs checks and tests on every push; the agent runs `builder ios release` from the Windows PC after each Bolt merges. The App Store Connect key stays on the PC.
- B. **Fully automatic in GitHub** — the key goes into the public repository's secrets.
- X. Other (please specify)

[Answer]: A

## Q2. GitHub repository name?
- A. **NBS1997/LidarApp**
- B. **NBS1997/ScanLab**
- X. Other (please specify)

[Answer]: B

## Q3. Bundle identifier?
- A. **com.nbs1997.scanlab**
- B. **com.scanlab**
- X. Other (please specify)

[Answer]: A

## Q4. May builder act on the Apple developer account (register the app ID, issue a distribution certificate and profile, store them as repository secrets)?
- A. **Yes, run it**
- B. **The owner runs it**
- X. Other (please specify)

[Answer]: A
