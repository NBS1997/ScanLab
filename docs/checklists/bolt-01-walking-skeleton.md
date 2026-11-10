# On-Device Checklist — Bolt 1, Walking Skeleton

Build: ScanLab 0.1.0, delivered through TestFlight (group "Owner").
Covers stories US-01 and US-02, and accessibility checks A1, A4, A12.
Tick each item on the phone. Anything that fails: note what you saw, and export the log
(item 9) if you can.

## Install

1. [ ] Open the **TestFlight** app. ScanLab appears with a build to install. Tap
   **Install**.
2. [ ] The home-screen icon is the blue rings over a dot grid, labelled **ScanLab**.

## First launch (US-01)

3. [ ] ScanLab opens on a screen titled **Scans** showing "No scans yet".
4. [ ] Tap **Diagnostics** (top left). Under **Build** you see:
   - [ ] **Version** `0.1.0 (n)`, where *n* matches the build number in TestFlight.
   - [ ] **Built**: today's date and a time.
   - [ ] **Build expires**: "in 89 days" or "in 90 days".

## Activity log (US-02)

5. [ ] Under **Activity**, the newest entries include **App launched** (with version,
   build and expiry) and **Library shown**.
6. [ ] Go back, then open Diagnostics again. Pull down on the list to refresh: a new
   **Library shown** entry has appeared.
7. [ ] **Force-quit** ScanLab (swipe up from the bottom, hold, swipe the app away).
   Reopen it and go to Diagnostics. The earlier entries are **still there**, plus a new
   **App launched**.
8. [ ] No line says "unreadable log line(s) skipped".
9. [ ] Tap **Export log** (bottom bar). The share sheet opens. Choose **Save to Files**
   and save it to iCloud Drive. On the Windows PC, the file opens as text and starts
   "ScanLab diagnostics log — N events".
10. [ ] Back in Diagnostics, a **Log export opened** entry has appeared.

## Accessibility and orientation

11. [ ] Turn the phone sideways on both screens: the layout rotates and nothing is cut
    off. Turn it back.
12. [ ] Settings › Accessibility › Display & Text Size › Larger Text: set the largest
    size. Both screens remain readable, with no clipped text. Set it back.
13. [ ] With VoiceOver on, swipe through Diagnostics: every item is read aloud with a
    sensible label.

## Result

- [ ] All passed — approve the walking skeleton.
- [ ] Something failed — describe it (and attach the exported log if possible).
