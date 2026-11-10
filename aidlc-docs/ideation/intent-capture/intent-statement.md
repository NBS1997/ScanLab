# Intent Statement — LidarApp

Source: the owner's project description and answers in
[intent-capture-questions.md](intent-capture-questions.md) (Q1–Q9).

## Problem Statement

The owner has an iPhone 17 Pro Max with a LiDAR sensor and no good way to use it for the
job they care about: turning a real object into a 3D model they can trust and design
around. A previous attempt, scanning the mounting for a Hobie kayak Mirage Drive with a
third-party app, failed on every front that matters (Q2):

- **Detail and accuracy.** The result was too coarse for a part of that size.
- **Capture process.** Tracking was lost, scans had to be repeated, and nothing indicated
  whether coverage was good enough.
- **Getting the result out.** Export was obstructed, and it took signing up to further
  services just to obtain a file that could be used.
- **Trust in dimensions.** The scale and measurements of the result could not be relied on.

Behind that sits a second problem of equal weight (Q1): the owner does not know what the
hardware is actually capable of. Existing apps hide the sensor behind a finished product,
so there is no first-hand way to see what it produces, where its limits are, or whether
the phone's cameras can add detail the depth sensor misses.

## Target Customer

One person: the owner, on their own phone (Q7). They are a hobbyist maker who designs
parts around existing objects and can produce 3D-printed parts. There are no other users,
no invited testers and no public release in view.

What they need from a scan is a **dimensionally trustworthy 3D model to use as a design
reference** (Q3). The objects are a mix of sizes with no single size dominating (Q4),
from small fittings up to larger assemblies.

## Success Metrics

| # | Metric | How it is measured | Target |
|---|---|---|---|
| S1 | **Known accuracy** | Scan a purpose-made reference object of known dimensions, covering a variety of shapes and sizes, and compare scanned dimensions with the known ones (Q9). | A measured error figure exists for each shape and size class on the reference object. |
| S2 | **Verified dimensions** | Dimensions taken from a scan of a real part are compared with caliper measurements (Q6-B). | Within the tolerance established by S1. The tolerance is set from S1's results, not assumed in advance (Q5, Q9). |
| S3 | **Hardware understood** | Each sensing capability the phone offers for scanning has been exercised through the app at least once, with its limits observed and written down (Q6-D). | 100% of the capabilities listed during feasibility are exercised and have a recorded finding. |
| S4 | **Third-party app replaced** | Whether the owner still needs the third-party app, or any other sign-up service, to get from a scan to a usable file (Q6-E, Q2). | Zero third-party apps or sign-up services needed for a scan of a real part, start to finish. |

One-pass capture and a short time-to-file were offered as metrics and **not selected**
(Q6-A, Q6-C). They are not success criteria for this initiative.

## Initiative Trigger

New hardware (Q8). The owner has the iPhone 17 Pro Max and wants to find out what it can
do. No deadline, external project or commercial pressure is driving the work.

## Initial Scope Signal

**MVP**, confirmed by the owner at workflow start. A single-user personal app delivered to
one phone through TestFlight. Market research, team formation and the operations phase
are out of scope.

Scope signals to carry into Feasibility and Scope Definition:

- **Two threads of equal weight** (Q1): capturing real parts, and exploring the hardware.
  Neither may be dropped to serve the other.
- **Cameras alongside the depth sensor** (Q4). The owner wants the phone's cameras used to
  add detail, for example edge detection, with correction for the offset between cameras
  that have different focal lengths. *Assumption:* whether this is achievable, and how
  much it improves a scan, is unknown until Feasibility examines it.
- **A reference object is part of the initiative** (Q9). Establishing accuracy depends on
  a purpose-made object of known dimensions. It is a deliverable alongside the app, not
  an afterthought.
- **Self-contained output** (Q2). Getting a usable file must not depend on signing up to
  another service.

## Open Assumptions

- *Assumption:* the hardware can produce results accurate enough to be useful as design
  reference for small parts. The Mirage Drive experience suggests this is not a given.
  S1 exists to replace this assumption with a measurement.
- *Assumption:* "usable file" means a file the owner's design tool accepts without an
  intermediate service. Which formats qualify is a question for Scope Definition.
