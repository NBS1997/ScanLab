# LidarApp — Security Rules

These are non-negotiable. Violations block a review regardless of context.

ScanLab has no server, no accounts and no network code (ADR-001). Its attack surface is
the files it writes and the files it reads, the camera permission, and the public
repository itself. The repository `NBS1997/ScanLab` is **public**, which drives most of
the rules below.

## Input Validation

- Validate all external input at the boundary, before it reaches business logic. The
  boundaries here are files and owner-typed values:
  - **Model files:** `OBJReader` (line-numbered errors, index checks), `MeshBinary.decode`
    (magic, exact length, indices in range → `StoreError.corrupt`), the STL reader in
    `Accuracy/STLReading.swift`, and `Mesh.init`, which throws `MeshError` on bad
    indices instead of crashing. All live in Core and are tested against malformed input
    (ADR-003).
  - **Manifests, reports and logs:** decoded tolerantly in Core (`ManifestCodec`,
    `LogCodec`); an unreadable scan or log line is counted and reported, not fatal.
  - **Caliper values:** `CaliperValidation` in `Accuracy/CaliperValues.swift` owns range
    and slip-of-the-pen checks (business rules AC-2 to AC-4).
  - **Scan names:** `ScanNaming`; export file names: `ExportNaming` (safe file names).
- Range checks, length caps and required-field checks are defined once in Core and
  reused, not reimplemented in screens.

## Injection Safety

- There is no database, query language, shell or template rendering in the app.
- **File paths:** the app only writes inside its own container (Application Support and
  the temporary folder). File names derived from owner input go through `ExportNaming`;
  scan folders are named by UUID, never by the scan's name.
- Path strings for `FileManager` come from `url.fileSystemPath`, never `url.path()`
  (ADR-021).
- Exports leave the app only through the system save chooser, at a location the owner
  picks.

## Secrets

- **Never commit signing keys, certificates, profiles or API keys** (project rule; the
  repository is public). `.gitignore` excludes `*.p12`, `*.p8`, `*.key`, `*.cer` and
  `*.mobileprovision`, and the first CI step fails the run if any such file is tracked.
- Where credentials actually live (ADR-016):
  - Signing key files: `C:\Users\natys\.scanlab-signing` on the owner's PC
    (`builder.json` points there).
  - Signing secrets for `ios-build.yml`: the GitHub repository's secret store, created by
    `builder signing setup`. They are not given to pull requests from forks.
  - The App Store Connect API key: builder's credential store on the PC only; it never
    enters GitHub.
- `ios-build.yml` is managed by `builder`; do not edit it by hand.
- `ci.yml` runs with `permissions: contents: read`; `reference-object.yml` is read-only
  and never pushes.
- Never log a secret, at any level. The app has none to log.

## Sensitive Data

- **Sensitive here:** photographs and depth data from captures (they may show the owner's
  surroundings), scan models, and caliper values. There is no personal information,
  location, financial or health data collected.
- All of it stays on the phone, in the app's own storage, protected by iOS data
  protection, unless the owner exports it through the save chooser (ADR-006, ADR-007).
  Camera frames during Explore and sweep capture are processed in memory and not stored;
  only the mesh is saved.
- **Never log** photographs, file contents or mesh data: the diagnostics log records
  event names, counts, durations and error reasons only (ADR-011). The exported log is
  plain text the owner may share, so treat every log line as public.
- No analytics, crash-reporting or third-party services (ADR-011, no-sign-up rule).
- The only protected capability is the camera (`NSCameraUsageDescription` in
  `project.yml`); permission denial is handled as a screen state.

## Dependencies

- **No third-party code ships in the app** (ADR-008), and nothing that costs money or
  needs an account may be added (project rule). Core has no package dependencies.
- Build-time tools only: XcodeGen and SwiftLint (installed on the runner with `brew`
  when missing; CI logs their versions), CadQuery 2.5.2 for the reference object (in
  `reference-object.yml`), and the builder CLI on the PC.
- Swift Package Manager has no audit command; with no package dependencies there is
  nothing to audit. Re-check this section if a dependency is ever added under ADR-008.
- If a CVE has no upstream fix, pin to the last safe version and record why here, with
  the date and the CVE reference. Pins without a recorded reason get "helpfully"
  upgraded later.
- Check licence compatibility before adding any new tool. The repository is MIT
  (ADR-015); copyleft code must not ship in the app.

Not settled by the sources: whether the GitHub Actions used (`actions/checkout@v4`,
`actions/setup-python@v5`) should be pinned to a commit SHA. The inception (ADR-014)
said third-party steps would be pinned to a commit; the current workflows use version
tags.

### Pinned for security

| Package | Pinned to | Reason | Date |
|---|---|---|---|
| — | — | Nothing pinned for security yet | — |
