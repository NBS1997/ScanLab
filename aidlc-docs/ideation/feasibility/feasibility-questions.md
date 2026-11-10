# Feasibility & Constraints — Clarifying Questions

> Context: [intent-statement.md](../intent-capture/intent-statement.md) describes a
> single-user LiDAR scanning app for the owner's iPhone 17 Pro Max, with two equal threads
> (capturing real parts, exploring the hardware), camera-assisted detail, and a 3D-printed
> reference object to establish accuracy. This workspace is a Windows machine. These
> questions establish what the app must fit in with and what limits the work.

## Q1. What access do you have to a Mac?
Building and signing an iPhone app needs Apple's tools, which only run on a Mac. This decides whether every build must happen on a hosted service.

- A. **None** — Windows only; every build runs on GitHub's hosted Mac machines.
- B. **Occasional** — a Mac I can borrow or use now and then, but not for day-to-day work.
- C. **Regular** — a Mac I can use whenever needed.
- X. Other (please specify)

[Answer]: A

## Q2. What is the state of your Apple developer account?
- A. **Paid membership, TestFlight already in use** for another app of mine.
- B. **Paid membership**, but TestFlight not yet used.
- C. **No paid membership yet.**
- X. Other (please specify)

[Answer]: A

## Q3. Your GitHub-to-TestFlight build workflow — what exists today?
- A. **Working end to end in another repository** and can be copied (please name the repository in the answer).
- B. **Partly working** — some pieces exist but it has not delivered a build to TestFlight yet.
- C. **Nothing yet** — it needs to be set up as part of this work.
- X. Other (please specify)

[Answer]: A — Nathans Fishing App (C:\Dev\Nathans-Fishing-App)

## Q4. Should this repository be public or private on GitHub?
GitHub's hosted Mac build time is free for public repositories and metered (and comparatively expensive) for private ones.

- A. **Public.**
- B. **Private**, and I accept that build minutes are limited or paid.
- C. **Not decided** — recommend based on cost.
- X. Other (please specify)

[Answer]: A

## Q5. Which tool must open the scan for it to count as "usable"? (select all that apply)
- A. **Autodesk Fusion** — as reference geometry to design around.
- B. **Blender** or another mesh editor.
- C. **A 3D-printing slicer** directly.
- D. **Not fixed** — any widely supported 3D file is fine.
- X. Other (please specify)

[Answer]: A, B, C

## Q6. What do you have for making and measuring the reference object? (select all that apply)
- A. **A 3D printer** I can use.
- B. **Digital calipers** (or similar) to measure the printed object and real parts.
- C. **CAD skills** to adjust the reference object's design myself.
- D. **None of these yet.**
- X. Other (please specify)

[Answer]: A, B, C

## Q7. How much iPhone app development experience do you have?
- A. **None** — I rely on the AI to write and explain the code.
- B. **Some** — I have shipped or modified an iPhone app before, with help.
- C. **Comfortable** — I can read and change the code myself.
- X. Other (please specify)

[Answer]: A

## Q8. Where may scan data go?
- A. **Stays on the phone**; I move files off it myself when I choose (for example, to my computer).
- B. **My own cloud storage is fine** (for example, iCloud Drive) if it makes transfer easier.
- C. **No preference.**
- X. Other (please specify)

[Answer]: B

## Q9. What limits apply to time and money?
- A. **Hobby pace, no deadline, no new spending** beyond what I already pay for.
- B. **Hobby pace, no deadline**, small extra costs are acceptable if they remove friction.
- C. **There is a date I am working towards** (please give it in the answer).
- X. Other (please specify)

[Answer]: A
