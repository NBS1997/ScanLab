# Domain Entities — U08 Photo Capture

Inputs: `component-methods.md` (`PhotoCapturing`, ScanLibrary `keepRawCapture`, `ScanStoring.rawCaptureURL`), `decisions.md` (ADR-006, ADR-007), `requirements.md` (FR-4, FR-6.6, FR-7.5), Apple's `PhotogrammetrySession` documentation (`Request.Detail`, `Poses`, `Output`).

All in Core `Capture/Photo/` (Foundation only) unless marked App.

| Entity | Fields / cases | Notes |
|---|---|---|
| `PhotoDetailLevel` | `preview`, `reduced`, `medium`, `full`, `raw`; `manifestValue` | iPhone offers only `reduced`. |
| `BuildStage` | `preparing`, `aligningPhotos`, `makingPoints`, `makingMesh`, `colouring`, `tidying`; `displayName` | Mirrors the platform's processing stages. |
| `BuildUpdate` | `fraction`, `stage?`, `secondsRemaining?` | One progress report. |
| `PhotoBuildResult` | `modelFile` (OBJ URL), `cameraPositions` (count), `route` (`obj` / `usdz-modelio`) | |
| `PhotoBuildEvent` | `photosRead`, `photoSkipped(reason)`, `progress(BuildUpdate)`, `built(PhotoBuildResult)` | Stream from `PhotoCapturing.build`. |
| `RawCaptureFolders` | `root`, `images`, `checkpoint`, `model`, `cameraPositions`, `readMe`; `keptNames` | Layout of one capture folder. |
| `PhotoCaptureError` | `unsupportedDevice`, `cameraDenied`, `tooFewImages(taken:minimum:)`, `captureFailed`, `buildFailed`, `noModel`, `noSpace`, `fileFailed`, `cancelled` | `errorDescription`, `logName`, `from(_:)`. |
| `PhotoCapturePhase` | `preparing`, `capturing(shots)`, `finishingCapture`, `readyToBuild(images)`, `building(BuildProgress)`, `saving`, `askingToKeep(KeepOffer)`, `done(PhotoCaptureOutcome)`, `failed(error, canBuildAgain)`, `cancelled(canBuildAgain)` | |
| `PhotoCaptureEvent` | `ready`, `resumed(images)`, `shotsTaken`, `captureFinishing`, `captureCompleted(images)`, `buildStarted(time)`, `buildProgressed(update, time)`, `modelBuilt`, `saved(KeepOffer)`, `rawCaptureDecided(keep)`, `failed`, `cancelled` | |
| `PhotoCaptureFlow` | `phase`; `apply(_:) -> Bool`, `canCancel`, `canBuild`, `isFinished`, `buildFraction`; `minimumImages = 10` | The state machine (PC-1–PC-4). |
| `BuildProgress` | `fraction`, `stage?`, `secondsRemaining?`, `updatedAt` | |
| `KeepOffer` | `scanID`, `scanName`, `images`, `rawBytes` | The keep question. |
| `PhotoCaptureOutcome` | `scanID`, `scanName`, `keptRawBytes?` | |
| `UnfinishedCapture` | `folders`, `images`, `bytes`, `modified` | A leftover capture (PC-9). |
| `CameraPosition` | `sample`, `imageName?`, `position` (Vec3, metres), `rotation` (`Quaternion` x, y, z, w), `intrinsics?` (`CameraIntrinsics` fx, fy, cx, cy px) | One CSV row. |
| `BackgroundBuildObserver` | `appLeft(at:fraction:)`, `buildEnded(_:)`, `appReturned(at:fraction:) -> Observation?`; `Observation` (`seconds`, `fractionBefore`, `fractionAfter`, `ending?`, `advanced`, `summary`, `logDetails`) | Open Question 3. |
| `camera-positions.csv` | `sample,image,x_m,y_m,z_m,qx,qy,qz,qw,fx_px,fy_px,cx_px,cy_px` | Six decimals for pose, three for lens; empty when unknown. |
| `README.txt` | Photo count, positions note, detail level | In every kept raw capture. |

## Ports and Services

| Name | Kind | Methods |
|---|---|---|
| `PhotoCapturing` | Port (Core) | `detailLevel`, `prepare() async throws`, `build(_ RawCaptureFolders) -> AsyncThrowingStream<PhotoBuildEvent, Error>` |
| `ObjectCapturePhotoCapture` | Adapter (App) | Implements the port with `ObjectCaptureSession.isSupported`, `PhotogrammetrySession`, AVFoundation permission, Model I/O fallback; `standardDirectory()`, `translate(_:)` |
| `ScanStoring` (additions) | Port (Core) | `attachRawCapture(from:to:)`, `removeRawCapture(for:)`, `rawCaptureFolder(for:)`; default answers for stores without support |
| `ScanLibrary` (additions) | Service (Core) | `keepRawCapture(_:from:)`, `discardRawCapture(_:)`, `rawCaptureFolder(for:)` |
| `PhotoModelImport` | Core | `modelFile(in:)`, `mesh(from:)`, `welded(_:)`, `sizeWarning(for:)` |
| `RawCaptureFiles` | Core | `bytes(in:)`, `imageCount(in:)`, `prepareForKeeping(_:detail:)`, `readMe(...)`, `unfinished(in:)`, `exportName(for:)`, `discard(_:)` |
| `RawCaptureExporter` | App | `zip(_:scanName:rawBytes:)`, `finish(_:outcome:)` |

## Storage

```
Application Support/PhotoCaptures/<capture id>/   while capturing and building
    Images/ Checkpoint/ Model/ camera-positions.csv
Application Support/Scans/<scan id>/RawCapture/    once kept
    Images/ camera-positions.csv README.txt
```
