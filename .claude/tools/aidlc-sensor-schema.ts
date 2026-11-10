// Sensor manifest schema — capability descriptor only. Sibling of
// aidlc-stage-schema.ts and aidlc-rule-schema.ts. Consumed by
// aidlc-graph compile (loadSensors). Hand-rolled, zero-dep — reuses
// scalarField from aidlc-lib.ts as a zero-dep YAML primitive.
//
// Pull authoring: manifests describe what the sensor IS, not which
// stages use it. The relationship lives on the stage side via
// `sensors: [<id>]` in stage frontmatter; the resolver looks each
// declared id up here at compile time.
//
// Schema:
//   - id: string                    — required; matches filename stem after
//                                      `aidlc-` prefix and before `.md`
//   - kind: "deterministic"         — required; sole accepted value today
//   - command: string               — required; sensor invocation
//   - default_severity: "advisory"  — required; sole accepted value today
//   - description: string           — required; one-line capability summary
//   - category: string              — optional grouping label
//   - input_schema: object          — optional invocation contract
//   - output_schema: object         — optional return contract
//   - timeout_seconds: number       — optional execution budget
//   - matches: string               — optional path-shape filter; consumed
//                                      by the PostToolUse hook at fire time.
//                                      Sensors that analyse any output omit it.
//
// Tolerates unknown keys for forward-compat (per 16-sensor-system.md).

import { scalarField } from "./aidlc-lib.ts";

export interface SensorManifest {
  id: string;
  kind: "deterministic";
  command: string;
  default_severity: "advisory";
  description: string;
  category?: string;
  input_schema?: Record<string, unknown>;
  output_schema?: Record<string, unknown>;
  timeout_seconds?: number;
  matches?: string;
}

const REQUIRED_FIELDS = [
  "id",
  "kind",
  "command",
  "default_severity",
  "description",
] as const;

// parseSensorManifest — extract the YAML frontmatter from a sensor manifest
// body. Throws when frontmatter is missing or malformed. Strips a UTF-8 BOM
// before matching so editors that add one don't silently drop the manifest.
export function parseSensorManifest(raw: string): SensorManifest {
  const cleaned = raw.charCodeAt(0) === 0xFEFF ? raw.slice(1) : raw;
  const m = cleaned.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!m) {
    throw new Error("Sensor manifest missing YAML frontmatter (---...---)");
  }
  const fm = m[1];

  const obj: Record<string, unknown> = {};

  // Scalar fields — read each known scalar via the zero-dep helper. Empty
  // string ("" return from scalarField when absent) is left out so
  // validateSensorManifest sees the genuinely-missing case.
  const id = scalarField(fm, "id");
  if (id !== "") obj.id = id;
  const kind = scalarField(fm, "kind");
  if (kind !== "") obj.kind = kind;
  const command = scalarField(fm, "command");
  if (command !== "") obj.command = command;
  const default_severity = scalarField(fm, "default_severity");
  if (default_severity !== "") obj.default_severity = default_severity;
  const description = scalarField(fm, "description");
  if (description !== "") obj.description = description;
  const category = scalarField(fm, "category");
  if (category !== "") obj.category = category;
  const matches = scalarField(fm, "matches");
  if (matches !== "") obj.matches = matches;
  const timeout = scalarField(fm, "timeout_seconds");
  if (timeout !== "") {
    const n = parseInt(timeout, 10);
    if (!Number.isNaN(n)) obj.timeout_seconds = n;
  }

  return obj as SensorManifest;
}

// validateSensorManifest — schema check on a parsed manifest. Throws
// "<file>: <message>" on the first violation, mirroring
// compileStageGraph's error pattern. Cross-checks `id:` against the
// filename stem (passed by the caller, who knows the path).
export function validateSensorManifest(
  obj: SensorManifest,
  file: string,
  filenameId: string,
): void {
  for (const field of REQUIRED_FIELDS) {
    if (!(field in obj) || (obj as Record<string, unknown>)[field] === undefined) {
      throw new Error(`${file}: missing required field: ${field}`);
    }
  }

  if (typeof obj.id !== "string" || obj.id.length === 0) {
    throw new Error(`${file}: id must be a non-empty string`);
  }
  if (obj.id !== filenameId) {
    throw new Error(
      `${file}: id "${obj.id}" must match filename stem "${filenameId}" ` +
        `(file should be aidlc-${obj.id}.md)`,
    );
  }

  if (obj.kind !== "deterministic") {
    throw new Error(
      `${file}: kind must be "deterministic" (got "${obj.kind}"); ` +
        `other kinds reserved for future releases`,
    );
  }

  if (typeof obj.command !== "string" || obj.command.length === 0) {
    throw new Error(`${file}: command must be a non-empty string`);
  }

  if (obj.default_severity !== "advisory") {
    throw new Error(
      `${file}: default_severity must be "advisory" (got "${obj.default_severity}")`,
    );
  }

  if (typeof obj.description !== "string" || obj.description.length === 0) {
    throw new Error(`${file}: description must be a non-empty string`);
  }

  if (obj.matches !== undefined) {
    if (typeof obj.matches !== "string" || obj.matches.length === 0) {
      throw new Error(`${file}: matches must be a non-empty string when present`);
    }
  }
}
