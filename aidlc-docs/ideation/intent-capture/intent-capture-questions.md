# Intent Capture — Clarifying Questions

> Initiative: **a dedicated LiDAR scanning app for the iPhone 17 Pro Max**, delivered to the
> owner's own phone through TestFlight. Already known from the description: the owner wants to
> explore what the LiDAR hardware can do, and a previous attempt to scan a Hobie kayak Mirage
> Drive mounting with a third-party app was painful. These questions pin down the problem, who
> it is for, and what success looks like. They stay at the problem level; technology choices
> come later.

## Q1. What is the PRIMARY purpose of this app?
Both threads are in the description. The primary one shapes what gets built first.

- A. **Capturing real parts** so they can be measured, modelled or reproduced (the Mirage Drive mounting case); exploration is secondary.
- B. **Exploring the hardware** — seeing what the sensor produces and where its limits are; part capture is secondary.
- C. **Equal weight** — neither leads.
- X. Other (please specify)

[Answer]: C

## Q2. What made the third-party app painful for the Mirage Drive mounting scan? (select all that apply)
- A. **Detail and accuracy** — the result was too coarse or lumpy for a part that size.
- B. **Capture process** — tracking loss, having to re-scan, no guidance on whether coverage was good enough.
- C. **Getting the result out** — export formats, paywalls, or heavy clean-up needed before it was usable.
- D. **Trust in dimensions** — scale or measurements could not be relied on.
- E. **Too many steps** from picking up the phone to having a usable file.
- X. Other (please specify)

[Answer]: A, B, C, D, X — having to sign up and then use other services just to get the file out in a usable form

## Q3. After a scan, what do you need to walk away with?
- A. **A dimensionally trustworthy 3D model** to use as a reference when designing a part around it.
- B. **Key measurements only** (distances, hole spacing, angles); a full model is a bonus.
- C. **A model good enough to reproduce directly** (for example, 3D print) with little rework.
- D. **A visual record** (model or point cloud) to look at; dimensions are not critical.
- X. Other (please specify)

[Answer]: A

## Q4. What size of thing will you mostly scan?
- A. **Small parts** — under about 15 cm (brackets, fittings, the drive itself).
- B. **Medium areas** — about 15 cm to 1 m (a mounting well, a section of hull, a dashboard).
- C. **Large objects and spaces** — over 1 m (a whole kayak, a room, a vehicle).
- D. **A mix** — no single size dominates.
- X. Other (please specify)

[Answer]: D, X — a mix; also wants to use the phone's cameras alongside LiDAR to add detail such as edge detection, correcting for the slight offset between cameras even where focal lengths differ

## Q5. How accurate does a scan need to be for you to call it usable?
- A. **About ±1 mm** — parts must fit together from the scan alone.
- B. **About ±2–5 mm** — good reference geometry; critical dimensions get checked with calipers.
- C. **About ±1 cm** — overall shape and layout is enough.
- D. **Not sure** — I want the app to show me what the hardware can actually achieve.
- X. Other (please specify)

[Answer]: D

## Q6. How will we know the app succeeded? (select all that apply)
- A. **One-pass capture** — a usable scan of a part on the first attempt, without re-scanning.
- B. **Verified dimensions** — measurements from a scan agree with calipers within the tolerance from Q5.
- C. **Short path to a usable file** — from opening the app to a file ready for the next tool, in a few minutes.
- D. **Hardware understood** — I have exercised each capability and know its limits first-hand.
- E. **Replaces the third-party app** — I no longer reach for it.
- X. Other (please specify)

[Answer]: B, D, E

## Q7. Who will use this app?
- A. **Just me**, on my own phone.
- B. **Me plus a few people I invite** through TestFlight.
- C. **Possibly the public later** — start personal, keep a public release open as an option.
- X. Other (please specify)

[Answer]: A

## Q8. Why now? What triggered this? (select all that apply)
- A. **New hardware** — the iPhone 17 Pro Max, and wanting to see what it can do.
- B. **A specific project** that needs scans soon (for example, more kayak fit-out work).
- C. **Frustration with existing apps** after the Mirage Drive scan.
- D. **Learning** — wanting to build and ship an iPhone app end to end.
- X. Other (please specify)

[Answer]: A

## Q9. (Follow-up) "Verified dimensions" (Q6) needs a tolerance, but Q5 was "not sure". How should the accuracy target be set?
- A. **Provisional ±2–5 mm** — a working target, revised after the first real measurements.
- B. **Measure first, then set** — no target up front; measure scan error on known objects and set the tolerance from the results.
- C. **±1 mm target** — aim for parts that fit from the scan alone.
- X. Other (please specify)

[Answer]: X — design a 3D-printed reference object with a variety of shapes and sizes, and use it to establish what the scanner achieves
