# Feasibility Assessment — LidarApp

Inputs: [intent-statement.md](../intent-capture/intent-statement.md) (success metrics
S1–S4) and [feasibility-questions.md](feasibility-questions.md) (Q1–Q9). Market research
was not run (out of `mvp` scope), so no competitive-analysis, market-trends or
build-vs-buy artefacts exist to draw on.

Evidence note: statements about what the phone can do come from Apple's published
developer documentation as known to the assessor, and from general published experience
with phone depth sensors. None has been confirmed on this device yet. Each is labelled
**assumption** where it has not been verified, and metric S3 ("hardware understood")
exists to replace those assumptions with observations.

## Verdict

**Feasible, with one significant uncertainty.** The app can be built, delivered and used
within the owner's constraints. What is not yet known is whether the result will be
accurate enough on small parts to be a trustworthy design reference. The initiative is
already shaped to answer that first (S1, the reference object), which is the right order.

| Area | Viability | Confidence |
|---|---|---|
| Building and delivering with no Mac | Viable | High — already working for another app |
| Capturing depth and 3D shape from the sensor | Viable | High |
| Accuracy good enough for small parts from the depth sensor alone | Doubtful | Low |
| Using the cameras to add detail | Viable in principle | Medium |
| Correcting for offsets between different cameras | Viable in principle, complex | Low–medium |
| Files that open in Fusion, Blender and a slicer | Viable | High |
| Getting files off the phone without a third-party service | Viable | High |
| Cost within "no new spending" | Viable | High |

## Technical Viability

### Building and delivery (Q1–Q4, Q9)

The owner has no Mac (Q1), a paid Apple developer membership with TestFlight in use (Q2),
and a working build-and-deliver workflow in the Nathans Fishing App repository (Q3). That
workflow runs on GitHub's hosted Mac machines, handles signing from stored secrets, and
already supports apps of the kind this one will be. A public repository (Q4) makes hosted
Mac build time free, which satisfies "no new spending" (Q9).

Consequences of having no Mac:

- **Every trial is a round trip.** A change is only seen on the phone after a hosted
  build and a TestFlight delivery. *Assumption:* tens of minutes per round trip, based on
  typical hosted build times. Work must be planned in small steps that are each worth a
  round trip.
- **No way to watch the app run from the computer.** Problems must be diagnosable from
  the phone itself, so the app needs to show and export its own diagnostic information.
- **The sensor cannot be imitated on a computer.** Anything that depends on real depth
  data can only be checked on the phone. Calculation logic that does not need the sensor
  can be checked automatically during the hosted build.

### Capture and accuracy (S1, S2)

- The depth sensor is designed for room-scale sensing. *Assumption:* it reports depth on
  a coarse grid, works from roughly a quarter of a metre to about five metres, and
  resolves surface features at the scale of a centimetre rather than a millimetre.
- For **medium and large** subjects (Q4 of intent capture: a mounting well, a section of
  hull, a whole kayak) this is likely to give usable overall shape and true scale.
- For **small parts** the depth sensor alone is unlikely to give dimensions a part can be
  designed against. This matches the owner's experience with the Mirage Drive mounting.
  *Hypothesis:* much of the "too coarse" result was the sensor's limit, not only the
  third-party app.

### Cameras alongside the depth sensor (intent statement scope signal)

- Building a model from many overlapping photographs captures far finer detail than the
  depth sensor, but photographs alone do not give reliable real-world size. The depth
  sensor does. Combining them, with photographs for detail and depth for scale, is the
  most promising route to a trustworthy model of a small part. The platform offers a
  built-in way to do this on the phone. *Assumption:* its accuracy on small mechanical
  parts is unverified and is exactly what S1 should measure.
- The phone reports, for each camera, the information needed to relate its image to the
  others (position offset and lens characteristics). Correcting for cameras with
  different focal lengths is therefore possible in principle. *Assumption:* using more
  than one rear camera at the same moment is supported but restricted, and combining
  them well is the most complex item in this initiative.
- Edge detection on camera images is well-established and low risk on its own. The
  uncertain part is tying detected edges back to real-world positions accurately.

### Output and transfer (S4, Q5, Q8)

- Fusion, Blender and slicers (Q5) all open common 3D surface-model files, so no
  third-party conversion service is needed.
- **Fusion is the demanding one.** It is built for precise solid shapes, and handles
  scanned surface models as reference only; very detailed scans make it slow, and
  turning a scan into an editable solid only works below a size limit. Scans will need
  to be exported at a controlled level of detail for Fusion.
- The owner's computer is Windows, so the phone's direct wireless sharing to a computer
  is not available. The owner's own cloud storage is acceptable (Q8) and avoids both a
  cable and any third-party sign-up.

### Reference object (S1, Q6)

The owner has a 3D printer, digital calipers and CAD skills (Q6), so the reference object
can be made and measured without outside help. Two cautions:

- A printed object is not exactly its design size. **The caliper measurement of the
  printed object is the truth**, not the design dimension.
- *Assumption:* depth sensors of this kind struggle with shiny, very dark and transparent
  surfaces. The reference object should be matt and light-coloured so that it measures
  the scanner, not the surface finish. Real parts with difficult surfaces are then a
  separate finding under S3.

## Risk Analysis

The full list is in [raid-log.md](raid-log.md). The three that matter most:

1. **Small-part accuracy may fall short** (R1). The headline use case, a part like the
   Mirage Drive mounting, sits where the depth sensor is weakest. Mitigation: measure
   first with the reference object (S1), and treat the photograph-plus-depth route as a
   core part of the work, not an optional extra.
2. **Slow trial loop with no Mac and no prior iPhone development experience** (R2, Q7).
   Each mistake costs a build round trip, and the owner relies on AI-written code.
   Mitigation: very small increments, an early end-to-end skeleton delivered to the
   phone, and built-in diagnostics.
3. **Multi-camera correction is the complexity sink** (R3). It could absorb most of the
   effort for an uncertain gain. Mitigation: sequence it after single-camera detail has
   been measured, and decide with numbers from S1 whether it is worth doing.

## Platform and Compliance Perspectives

- **Cloud platform:** no cloud backend is needed. Nothing runs on servers; the only
  hosted services are the build service and the owner's own cloud storage. No cloud
  account, cost or security review applies.
- **Regulatory:** none identified. The app has one user, collects no data about other
  people, and sends nothing to a third party. Obligations that do apply are in
  [constraint-register.md](constraint-register.md): the platform's permission prompts
  for camera use, the distribution questionnaire about encryption, and keeping signing
  secrets out of a public repository.
