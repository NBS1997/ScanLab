# Code Summary — U14 Depth Fusion (Bolt 13)

## Core (`Packages/ScanLabCore/Sources/ScanLabCore/Fusion`)

| File | What it does |
|---|---|
| `FusionSettings.swift` | All tunable numbers (DF-1 to DF-6), with log details. |
| `FusionFrame.swift` | One depth picture with lens numbers and camera position; camera ↔ world conversions. Extends the existing `CameraIntrinsics` (shared with photo capture) with `scaled(by:)` and `isUsable`. |
| `VoxelVolume.swift` | Sparse grid of 8 × 8 × 8 blocks with flat distance, weight and picture-number arrays; memory cap; one change per cube per picture. |
| `DepthFusion.swift` | Range and confidence weighting; finds cubes along each line of sight and judges each by projecting it into the depth picture (bilinear depth, nearest across edges). |
| `SurfaceNets.swift` | Draws the surface: one corner per crossed cell, outward-facing quads. |
| `MeshPieces.swift` | Union-find over shared corners; drops pieces under 60 triangles. |

Changed: `SweepProgress` gains `fusedFrames`, `fusionFull` and `prompt`; `CaptureText.stats`
adds the depth-picture count.

## App (`App/Sources/Capture`)

| File | What it does |
|---|---|
| `FusionWorker.swift` | Runs `DepthFusion` on its own serial queue; times pictures and extraction. |
| `ARKitSweepCapture.swift` | Turns on `.sceneDepth`; `SweepReceiver` feeds one picture at a time while tracking is normal, counts skipped pictures, logs memory full; Finish chooses the fused model or falls back to the scene mesh, and logs which. |
| `SweepReceiver+Copying.swift` | ARKit → Core copying moved out of the receiver: mesh anchors (unchanged) and depth frames (new). |
| `CaptureModel.swift` | Uses `SweepProgress.prompt`. |

## Tests

`DepthFusionTests` (synthetic wall and sphere from 12 cameras: mean error under 1 mm
noise-free, under 1.5 mm with ±3 mm noise, faces outward, bad readings ignored, memory
cap, projection and depth blending), `FusionPartsTests` (voxel indexing including
negative positions, once-per-picture rule, weight cap, stamp wrap, mesh pieces, progress
prompt and stats text). CI run 43204027863: 427 tests passed, Core coverage 98.9%, app
builds.

## Not testable in CI

Real depth pictures, lens numbers and camera poses from ARKit; speed on the phone. See
`docs/checklists/bolt-13-depth-fusion.md`.
