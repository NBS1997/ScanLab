# Domain Entities — U14 Depth Fusion

All in Core (`Packages/ScanLabCore/Sources/ScanLabCore/Fusion`), Foundation only (ADR-003).

| Entity | What it is |
|---|---|
| `FusionSettings` | Every tunable number in one place: voxel size, band, depth range, confidence weights, weight cap, minimum weight to draw, memory cap, smallest piece kept. |
| `CameraIntrinsics` | The camera's focal lengths and centre, in pixels. The platform gives them for the colour picture; `scaled(by:)` turns them into the depth picture's size. |
| `FusionFrame` | One depth picture (`DepthFrame`), its intrinsics and the camera's position and direction in the world (`cameraToWorld`). Camera axes follow the platform: x right, y up, looking along −z. |
| `VoxelVolume` | The sparse grid: only blocks of 8 × 8 × 8 cubes near seen surfaces exist, kept in a dictionary keyed by block position. Each cube stores a distance and a weight. |
| `DepthFusion` | Fuses frames into a `VoxelVolume` and keeps `FusionStats`. Not thread-safe: the App keeps it on one queue. |
| `FusionStats` | Pictures fused, readings used, blocks in use, whether memory is full. |
| `SurfaceNets` | Draws the surface from the volume: one corner per cube-cell the surface passes through, joined into faces facing outwards. |
| `MeshPieces` | Splits a mesh into joined pieces and drops the small ones. |
| `FusedMesh` | The result: the mesh and how many pieces and faces were dropped. |
