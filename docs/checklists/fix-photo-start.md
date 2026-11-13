# On-Device Checklist — Fix: photo capture start (build 9)

Build 8 fault: Photos opened, Apple's aiming brackets showed, but only **Cancel** and
"0 photos" appeared underneath, and no photos were ever taken. The capture session
became ready before ScanLab started listening, so the object was never looked for.
Build 9 reads the session's state as soon as it starts listening.

You need: the servo (or any small part) on a plain table, good light.

1. [ ] New scan → Photos. Under the camera, a line says what to do next. Within a
   second or two it reads "Point at the part on a flat surface. Tap Find object, or
   Start without box." and the buttons are **Cancel**, **Find object** and **Start
   without box**. No photo count is shown yet.
2. [ ] Point at the part. Apple draws a box round it; the line reads "Box found…" and
   the button becomes **Start capture**. (If no box comes, tap **Find object** or use
   **Start without box**.)
3. [ ] Tap **Start capture**. The photo count appears and **rises on its own** as you
   walk slowly round the part ("Walk slowly round the part. Photos are taken on their
   own.").
4. [ ] Go all the way round, then **Finish**. The model builds and saves, or an error is
   shown. Either way, note what happened.
5. [ ] Diagnostics, under `photo`: **Session state** entries (ready, detecting,
   capturing…), **Looking for the object**, **Capture button tapped**, **Taking
   photos**. If capture fails, **Capture session failed** with a reason: send me the
   log, because that would be the iPhone 17 Pro fault reported to Apple.
