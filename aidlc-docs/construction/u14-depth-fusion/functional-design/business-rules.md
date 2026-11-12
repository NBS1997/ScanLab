# Business Rules — U14 Depth Fusion

Inputs: owner feedback on build 6 (2026-11-12: "the scans are rough and really not very
detailed … the hardware is capable but we will need more software"), the decision point
after step 4 in `bolt-plan.md`, `intent-backlog.md` (B17), U07 business rules (SC-1 to
SC-13 still apply), ADR-003, ADR-005, ADR-011, ADR-029.

## Why

The sweep built its model from the platform's scene mesh, which is made for rooms
(hiding virtual objects behind furniture). Its triangles are centimetres across and it
smooths away small detail. The LiDAR's own depth picture (256 × 192 readings, each with
a confidence) is far finer. U14 builds the sweep model from those readings instead.

## Rules

| ID | Rule | Origin |
|---|---|---|
| DF-1 | While a sweep runs and tracking is normal, depth pictures are fused into a grid of small cubes ("voxels", 4 mm). Each reading updates the cubes along its line of sight within ±16 mm of the measured surface with a signed distance: positive in front of the surface, negative behind. Cubes keep a weighted average. One picture changes a cube at most once, so it counts as one view however many of its readings pass through the cube. | B17 |
| DF-2 | Readings count only between 10 cm and 1.0 m. Low-confidence readings are ignored; medium counts 0.35 of a high reading. A cube's weight stops growing at 64, so later views can still correct it. | B17, NFR-F2 |
| DF-3 | The surface is drawn where the averaged distance changes sign, between cubes that have each been seen with a weight of at least 1.5 (at least two high-confidence pictures, or five medium). Cubes seen once are not trusted. | B17 |
| DF-4 | Pieces of surface smaller than 60 triangles, not joined to anything else, are dropped as noise. | B17 |
| DF-5 | One depth picture is fused at a time. Pictures that arrive while the last one is still being fused are skipped and counted; the camera never waits. | NFR-F1 |
| DF-6 | Fusion memory is capped at 12,000 blocks of 8 × 8 × 8 cubes (about 60 MB). When full, no new areas are added, existing ones keep improving, and the screen says "Detail memory full. Finish now, or start again closer to the subject." | NFR-F2 |
| DF-7 | Finish saves the fused model. If fusion produced nothing (for example, no depth pictures arrived), the platform's scene mesh is saved instead, and the log says which was used. | SC-7 |
| DF-8 | The fused model is in the platform's y-up world, in metres, so it goes through the same turn-upright, save and export path as before (SC-5). | ADR-025 |
| DF-9 | The Capture screen shows how many depth pictures have been fused. The live wireframe still shows the platform's scene mesh as a guide to coverage. | project rule (diagnostics) |
| DF-10 | The diagnostics log records, under `capture`: fusion settings at start, the first time memory fills, and at finish the pictures fused and skipped, readings used, blocks, average milliseconds per picture, extraction time, pieces dropped, faces, and which model was saved. | project rule (diagnostics) |

**All numbers above are first guesses**, to be tuned against the reference object on
the phone. They live together in `FusionSettings`.
