# NFR Requirements and Design — U14 Depth Fusion

| ID | Requirement | Design |
|---|---|---|
| NFR-F1 | The camera and the live wireframe must not slow down while fusing. | Fusion runs on its own serial queue. The ARKit delegate only copies the depth picture (about 0.3 MB) and hands it over; if fusion is busy the picture is skipped (DF-5). Holding `ARFrame`s is avoided, as it stalls the camera. |
| NFR-F2 | Memory stays bounded on long sweeps. | Sparse blocks with a hard cap (DF-6), about 60 MB at most. |
| NFR-F3 | Finish completes in a few seconds for a typical part. | Surface extraction is one pass over stored cubes; its time is logged (DF-10) so it can be measured on the phone. |
| NFR-F4 | The fusion maths is testable without the phone. | Pure Swift in Core. Tests build synthetic depth pictures of a plane and a sphere from known camera positions and check the fused surface lies within a set distance of the true shape, faces outwards, and ignores bad readings. |
| NFR-F5 | Performance is visible on the phone. | Average milliseconds per picture, pictures skipped and extraction time are logged (DF-10). |

## Design choices (ADR-029)

- **Signed-distance fusion on the CPU, in Core.** Chosen over Metal on the GPU: testable
  in CI with the rest of Core and readable for the owner. Metal remains an option if the
  phone shows fusion is too slow.
- **Surface nets instead of marching cubes** to draw the surface: no 256-case lookup
  tables, one shared corner per cell (fewer, better-shaped triangles that the existing
  simplifier handles well).
- **Ray-band update**: each reading updates only the cubes near its own surface point,
  which keeps the work proportional to the number of readings.
