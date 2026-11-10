# Platform Verification — LidarApp

Research carried out 2026-11-10 by a research agent reading Apple, GitHub and Autodesk
documentation. It checks the assumptions logged in the feasibility RAID log (A1–A8).
"Confirmed" means a source page was read and says so. Nothing here has been observed on
the owner's phone yet; metric S3 still stands.

## Findings

| # | Assumption | Result | Fact |
|---|---|---|---|
| V1 | The depth sensor reports a coarse grid | Confirmed | ARKit scene depth is 256 × 192 with a low/medium/high confidence value per pixel. The camera framework's LiDAR depth camera streams depth up to 320 × 240 and gives 768 × 576 for a still photo, but that path does not include ARKit's motion tracking. Figures come from a 2022 Apple talk; the formats on this phone must be read at runtime. |
| V2 | Depth range about 0.25–5 m | Partly | 5 m maximum confirmed. The 0.25 m minimum could not be verified. |
| V3 | The platform builds a surface mesh from the depth sensor | Confirmed | ARKit scene reconstruction provides a mesh of the surroundings. Apple states no accuracy; it is oriented to rooms, not small parts. |
| V4 | The platform has a built-in photographs-to-model capability that runs on the phone | Confirmed, with a significant limit | Object Capture runs on the phone (iOS 17 and later, LiDAR required). **On the phone only the "reduced" detail level is available**; medium, full and raw need a Mac. Output is USDZ or OBJ, plus point cloud and camera poses. An "area mode" exists since iOS 18. No accuracy or object-size figures are published. Real-world scale from LiDAR is implied but not stated outright. |
| V5 | Camera offsets and lens characteristics are available | Confirmed | Per-frame intrinsics, extrinsics, pixel size and lens-distortion tables are exposed. |
| V6 | More than one rear camera can run at once | Confirmed, restricted | Supported through a multi-camera session, limited to device-defined camera sets and formats, discoverable only at runtime. |
| V7 | iPhone 17 Pro Max hardware | Confirmed | Three 48 MP rear cameras: 24 mm main, 13 mm ultra-wide, 100 mm (4×) telephoto; LiDAR scanner. Shipped with iOS 26; iOS 27.2.1 is current. |
| V8 | TestFlight builds expire after about 90 days | Confirmed | 90 days. Internal testers get builds without the external beta review. |
| V9 | Hosted Mac builds are free for public repositories | Confirmed | Free and unlimited on standard runners. `macos-26` (Xcode 26.x, iOS 26 SDKs) meets Apple's current upload requirement. An `xcode-27` image exists as a public preview. Runners are 3-core, 7 GB memory, 14 GB disk. |
| V10 | Meshes can be exported without third-party libraries | Partly | OBJ and STL export are documented. PLY and USD export are unconfirmed; check on the device. |
| V11 | Fusion accepts scan meshes | Confirmed, with a tight limit | Insert Mesh accepts STL, OBJ and 3MF. Autodesk says mesh-to-solid conversion works best under 10,000 facets and may fail above that. |
| V12 | Sensor code can be checked in the hosted build | Corrected | Depth and Object Capture code does not run (and the sample does not compile) for the simulator. The hosted build can compile for the device and unit-test sensor-independent logic only. |

## What This Changes

1. **Photograph-based capture on the phone is capped at reduced detail** (V4). Feasibility
   called photographs-plus-depth "the most promising route" for small parts. It still is
   the route to try, but its ceiling is lower than assumed and there is no Mac to raise
   it. Risk R1 (small-part accuracy) is more likely than feasibility rated it. The raw
   photographs and poses can be kept, so a higher-detail rebuild elsewhere later is not
   ruled out.
2. **Fusion's practical limit is about 10,000 facets** for conversion to a solid (V11).
   The "Fusion-friendly" export level must target that figure, and Fusion use beyond
   that is as visual reference only.
3. **A higher-resolution depth still (768 × 576) exists** (V1) outside ARKit. It is a
   third capture source worth exploring under S3.
4. **The first delivery should include a screen that lists what this phone actually
   reports** (V1, V6, V10): depth formats, multi-camera sets, exportable file types.
5. **The phone may be on iOS 27** (V7). An app built with the iOS 26 tools is expected to
   run on it (inference); anything needing iOS 27 features would depend on a preview
   build image.

## Sources

- developer.apple.com: ARKit scene depth, ARDepthData, scene reconstruction, ARCamera
  intrinsics; AVFoundation calibration data and multi-camera session; RealityKit
  PhotogrammetrySession request and detail, "Scanning objects using Object Capture";
  WWDC22 session 110429, WWDC23 session 10191, WWDC24 session 10107; Model I/O asset
  file types and export check; App Store Connect help (internal and external testers);
  upcoming requirements.
- support.apple.com: iPhone 17 Pro Max technical specifications; software versions.
- docs.github.com: GitHub-hosted runners; actions/runner-images macOS 26 and Xcode 27
  image readmes.
- help.autodesk.com: Insert Mesh; converting a mesh to a solid body.
