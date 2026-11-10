# ScanLab

A personal iPhone app for exploring the LiDAR scanner on an iPhone 17 Pro Max and for
turning real parts into 3D models whose dimensions can be trusted. The repository is
named LidarApp locally and `NBS1997/ScanLab` on GitHub; the app is called ScanLab.

Built with the AI-DLC workflow: the reasoning behind every decision is in
[`aidlc-docs/`](aidlc-docs/), starting with the
[intent statement](aidlc-docs/ideation/intent-capture/intent-statement.md) and the
[architecture decisions](aidlc-docs/inception/application-design/decisions.md).

## Layout

| Path | What it is |
|---|---|
| `App/` | The iPhone app: SwiftUI screens and the adapters that use the phone's sensors |
| `Packages/ScanLabCore/` | Logic that needs no sensor (geometry, export, accuracy, diagnostics), tested on every push |
| `project.yml` | XcodeGen manifest; the Xcode project is generated, never committed |
| `.github/workflows/ci.yml` | Lint, format, Core tests with an 80% coverage floor, unsigned app compile |
| `.github/workflows/ios-build.yml` | Signed builds, managed by the `builder` tool |

## Building without a Mac

Everything is built on GitHub's hosted Macs. Delivery to TestFlight runs from a Windows
PC with the `builder` tool:

```bash
builder ios release --profile store
```

## Licence

MIT — see [LICENSE](LICENSE).
