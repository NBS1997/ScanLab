// Runtime-graph compile + read tool. Materialises a per-workflow
// runtime-graph.json from audit.md + per-stage memory.md files; the
// data-plane mirror of stage-graph.json (which is structural truth).
//
// Subcommands:
//   compile [--test-run]          Walk audit + memory, write runtime-graph.json
//   read    <stage-slug>          Print one stage row from runtime-graph.json
//
// The compile subcommand is invoked by the PostToolUse Bash hook
// (aidlc-runtime-compile.ts) on every transition-class audit emit. Pure
// observer — never mutates state.md, never asks the user, only reads the
// audit log + memory.md files and writes runtime-graph.json + emits
// MEMORY_EMPTY rows for zero-entry approved stages.
//
// Schema is locked in docs/reference/19-runtime-graph.md and pinned by
// the test suite. Changing the shape requires bumping every consumer
// (Bolt fork/merge, gate ritual, lifecycle, doctor) in the same MR.
//
// Determinism: re-running compile against the same audit log produces a
// byte-equivalent runtime-graph.json. Emitted MEMORY_EMPTY rows are
// re-emitted on re-compile (append-only audit, no row de-duplication);
// the doctor de-duplicates by (Stage, ISO-second) tuple when computing
// the MEMORY_EMPTY-rate metric.

import {
  loadStageGraph,
  findAllEvents,
  withAuditLock,
  writeFileAtomic,
  resolveProjectDir,
  readStateFile,
  getField,
  parseMemoryHeadings,
  auditFilePath,
  stateFilePath,
} from "./aidlc-lib.ts";
import { appendAuditEntryUnlocked } from "./aidlc-audit.ts";
import { readFileSync, existsSync } from "fs";
import { join } from "path";

// --- Schema (must match docs/reference/19-runtime-graph.md exactly) ---

interface MemoryBreakdown {
  interpretations: number;
  deviations: number;
  tradeoffs: number;
  open_questions: number;
}

interface SensorFiring {
  id: string;
  result: "passed" | "failed";
  ts: string;
  detail_path?: string;
}

interface BoltInstance {
  bolt: string;
  worktree: string;
  started_at: string;
  completed_at: string | null;
  memory_path: string;
  memory_entries: number | null;
  memory_breakdown: MemoryBreakdown | null;
  sensor_firings: SensorFiring[];
  outcome: "approved" | "failed" | "pending";
}

interface RuntimeStage {
  stage_slug: string;
  // Single-instance fields (started_at, completed_at, agent, memory_path,
  // memory_entries, memory_breakdown) are NULL when `instances` is present —
  // those values sit on each BoltInstance instead. memory_path stays populated
  // even on instance-bearing rows (it's the parent stage's path).
  started_at: string | null;
  completed_at: string | null;
  agent: string | null;
  memory_path: string;
  memory_entries: number | null;
  memory_breakdown: MemoryBreakdown | null;
  sensor_firings: SensorFiring[];
  outcome: "approved" | "failed" | "pending";
  learnings_captured: {
    from_orchestrator: number;
    from_user_addition: number;
  } | null;
  instances?: BoltInstance[];
}

interface RuntimeGraph {
  workflow_id: string;
  scope: string;
  started_at: string;
  stages: RuntimeStage[];
}

// --- Path helpers ---

function runtimeGraphPath(projectDir: string): string {
  return join(projectDir, "aidlc-docs", "runtime-graph.json");
}

function memoryPath(projectDir: string, phase: string, stageSlug: string): string {
  return join(projectDir, "aidlc-docs", phase, stageSlug, "memory.md");
}

// Memory path to record on the row, relative to projectDir, forward slashes
// regardless of host OS — keeps the schema portable across worktrees.
function memoryPathForRow(phase: string, stageSlug: string): string {
  return `aidlc-docs/${phase}/${stageSlug}/memory.md`;
}

// --- Compile ---

interface CompileOptions {
  testRun: boolean;
  projectDir: string;
}

// Walk the audit log chronologically and build a per-slug map of
// {started_at, completed_at, agent}. Pairing rule: STARTED@T1 with
// later COMPLETED@T2 → approved (completed_at = T2). STARTED with no
// later COMPLETED for that slug → pending. A re-jump that re-emits
// STAGE_STARTED for an already-completed slug resets the entry, so
// the latest STAGE_STARTED wins (the row reflects current intent).
//
// One row per slug. Sub-second timestamp collisions resolve via
// findAllEvents source-line order (deterministic per CRLF-normalised
// audit walk).
interface PairingEntry {
  started_at: string;
  completed_at: string | null;
  agent: string;
  // Source-position index of this slug's latest STAGE_STARTED in the merged
  // chronological stream. Used as the tie-breaker when two stages share an
  // ISO-second started_at, so the row ordering remains deterministic.
  startedIndex: number;
}

function pairStartedCompleted(
  audit: string,
  sinceTimestamp: string
): Map<string, PairingEntry> {
  // findAllEvents returns chronologically (source-position-ordered) blocks.
  // sinceTimestamp filters out rows from prior workflows on the same
  // audit log (the `--init --force` re-init case appends without truncating).
  const startedEvents = findAllEvents(audit, "STAGE_STARTED").filter(
    (e) => e.timestamp >= sinceTimestamp
  );
  const completedEvents = findAllEvents(audit, "STAGE_COMPLETED").filter(
    (e) => e.timestamp >= sinceTimestamp
  );

  // Merge into a single chronological stream. ISO timestamps sort
  // lexicographically; ties broken by source-position by tagging each
  // event with its index in findAllEvents output (which is already
  // source-position-ordered).
  const stream: Array<{
    kind: "STARTED" | "COMPLETED";
    timestamp: string;
    block: string;
    index: number;
  }> = [];
  startedEvents.forEach((e, i) =>
    stream.push({ kind: "STARTED", timestamp: e.timestamp, block: e.block, index: i })
  );
  completedEvents.forEach((e, i) =>
    stream.push({ kind: "COMPLETED", timestamp: e.timestamp, block: e.block, index: i + 100000 })
  );
  stream.sort((a, b) => {
    if (a.timestamp !== b.timestamp) return a.timestamp < b.timestamp ? -1 : 1;
    return a.index - b.index;
  });

  const map = new Map<string, PairingEntry>();
  let sourceIndex = 0;
  for (const ev of stream) {
    const stageMatch = ev.block.match(/^\*\*Stage\*\*:\s*(\S+)/m);
    if (!stageMatch) continue;
    const slug = stageMatch[1].trim();

    if (ev.kind === "STARTED") {
      const agentMatch = ev.block.match(/^\*\*Agent\*\*:\s*(.+)$/m);
      const agent = agentMatch ? agentMatch[1].trim() : "";
      map.set(slug, {
        started_at: ev.timestamp,
        completed_at: null,
        agent,
        startedIndex: sourceIndex++,
      });
    } else {
      const entry = map.get(slug);
      if (entry && entry.completed_at === null) {
        entry.completed_at = ev.timestamp;
      }
    }
  }
  return map;
}

// Build the workflow-level fields (workflow_id, scope, started_at) from
// audit + state. workflow_id is the LATEST WORKFLOW_STARTED timestamp —
// `--init --force` re-init appends a new WORKFLOW_STARTED without
// truncating audit.md, and the live workflow is the latest one. Using
// the first row would identify a dead workflow.
function buildWorkflowHeader(
  audit: string,
  stateContent: string | null
): { workflow_id: string; scope: string; started_at: string } | null {
  const started = findAllEvents(audit, "WORKFLOW_STARTED");
  if (started.length === 0) return null;
  const latest = started[started.length - 1];
  const scopeFromAudit = latest.block.match(/^\*\*Scope\*\*:\s*(.+)$/m);
  const scopeFromState = stateContent ? getField(stateContent, "Scope") : null;
  const scope = scopeFromState || (scopeFromAudit ? scopeFromAudit[1].trim() : "");
  return {
    workflow_id: latest.timestamp,
    scope,
    started_at: latest.timestamp,
  };
}

// Build a phase-by-slug lookup from stage-graph.json. Reuses the
// in-memory cache; no per-compile re-parse.
function buildPhaseMap(): Map<string, { phase: string; agent: string }> {
  const stages = loadStageGraph();
  const map = new Map<string, { phase: string; agent: string }>();
  for (const s of stages) {
    map.set(s.slug, { phase: s.phase, agent: s.lead_agent });
  }
  return map;
}

// Read memory.md for a stage and return entries + breakdown. Returns
// null/null when the file does not exist (backfill rule for stages
// that completed before memory.md tracking shipped); zero counts when
// the file exists but has no entries.
function readMemory(
  projectDir: string,
  phase: string,
  stageSlug: string
): { memory_entries: number | null; memory_breakdown: MemoryBreakdown | null } {
  const path = memoryPath(projectDir, phase, stageSlug);
  if (!existsSync(path)) {
    return { memory_entries: null, memory_breakdown: null };
  }
  const raw = readFileSync(path, "utf-8");
  const parsed = parseMemoryHeadings(raw);
  return {
    memory_entries: parsed.total,
    memory_breakdown: {
      interpretations: parsed.interpretations,
      deviations: parsed.deviations,
      tradeoffs: parsed.tradeoffs,
      open_questions: parsed.open_questions,
    },
  };
}

// --- Compile core ---

function compile(opts: CompileOptions): { skipped?: string; written?: string } {
  const { projectDir, testRun } = opts;
  const auditPath = auditFilePath(projectDir);

  // Env-misconfig fallback per plan §97-102.
  const statePath = stateFilePath(projectDir);
  if (!existsSync(statePath)) {
    process.stderr.write(
      "runtime-compile: no aidlc-state.md, skipping (likely pre-init)\n"
    );
    return { skipped: "no-state" };
  }
  if (!existsSync(auditPath)) {
    // No audit yet — write an empty graph anchored to state cursor only,
    // mirroring the "fresh init, no transitions" case.
    return writeEmptyGraph(projectDir);
  }

  const audit = readFileSync(auditPath, "utf-8");
  const stateContent = readStateFile(projectDir);

  const header = buildWorkflowHeader(audit, stateContent);
  if (!header) {
    return writeEmptyGraph(projectDir);
  }

  const pairing = pairStartedCompleted(audit, header.started_at);
  const phaseMap = buildPhaseMap();

  // Build stage rows in chronological order (sorted by started_at, ties
  // broken by source-position to keep ordering deterministic across runs).
  const slugsByStartTime = [...pairing.entries()].sort((a, b) => {
    if (a[1].started_at !== b[1].started_at) {
      return a[1].started_at < b[1].started_at ? -1 : 1;
    }
    return a[1].startedIndex - b[1].startedIndex;
  });

  const stages: RuntimeStage[] = [];
  const zeroEntryApprovedStages: { slug: string; completed_at: string }[] = [];

  for (const [slug, entry] of slugsByStartTime) {
    const phaseInfo = phaseMap.get(slug);
    if (!phaseInfo) continue; // unknown slug — skip rather than fail

    const memory = readMemory(projectDir, phaseInfo.phase, slug);
    const outcome: RuntimeStage["outcome"] =
      entry.completed_at !== null ? "approved" : "pending";

    stages.push({
      stage_slug: slug,
      started_at: entry.started_at,
      completed_at: entry.completed_at,
      agent: entry.agent || phaseInfo.agent,
      memory_path: memoryPathForRow(phaseInfo.phase, slug),
      memory_entries: memory.memory_entries,
      memory_breakdown: memory.memory_breakdown,
      sensor_firings: [],
      outcome,
      learnings_captured:
        outcome === "approved"
          ? { from_orchestrator: 0, from_user_addition: 0 }
          : null,
    });

    // MEMORY_EMPTY emit applies to approved rows only with memory_entries === 0.
    // We capture the slug's completed_at so the locked section can suppress
    // re-emits — exactly one MEMORY_EMPTY per (slug, gate-completion) tuple.
    // Re-jump + re-approve produces a new completed_at, so a still-empty
    // stage on re-approval emits again (the suppression check is "since
    // THIS approval's completed_at", not "ever").
    if (outcome === "approved" && memory.memory_entries === 0) {
      zeroEntryApprovedStages.push({ slug, completed_at: entry.completed_at! });
    }
  }

  const graph: RuntimeGraph = {
    workflow_id: header.workflow_id,
    scope: header.scope,
    started_at: header.started_at,
    stages,
  };

  // Audit-first inside ONE locked section: emit MEMORY_EMPTY rows first,
  // then write the artefact. Re-emit suppression: re-read audit inside the
  // lock and skip any (slug) that already has a MEMORY_EMPTY row whose
  // Timestamp >= the slug's current completed_at — gives exactly one
  // MEMORY_EMPTY per (slug, gate-completion) tuple, so doctor's rate
  // metric is honest under N-compile-per-workflow re-fires.
  withAuditLock(projectDir, () => {
    const auditNow = readFileSync(auditPath, "utf-8");
    const existingEmpties = findAllEvents(auditNow, "MEMORY_EMPTY");

    for (const ze of zeroEntryApprovedStages) {
      // Skip if any MEMORY_EMPTY for this slug already lies at or after
      // this approval's completed_at — we've already recorded the skip
      // for this gate-completion.
      const alreadyEmitted = existingEmpties.some((ev) => {
        const stageMatch = ev.block.match(/^\*\*Stage\*\*:\s*(\S+)/m);
        if (!stageMatch || stageMatch[1].trim() !== ze.slug) return false;
        return ev.timestamp >= ze.completed_at;
      });
      if (alreadyEmitted) continue;

      const fields: Record<string, string> = { Stage: ze.slug };
      if (testRun) {
        fields["Test-Run"] = "true";
      }
      appendAuditEntryUnlocked("MEMORY_EMPTY", fields, projectDir);
    }
    writeFileAtomic(runtimeGraphPath(projectDir), JSON.stringify(graph, null, 2) + "\n");
  });

  return { written: runtimeGraphPath(projectDir) };
}

// Empty-graph short-circuit for the "state exists, no audit / no
// WORKFLOW_STARTED" cases. Writes a valid graph with empty stages array
// so downstream readers don't have to special-case absence.
function writeEmptyGraph(projectDir: string): { written: string } {
  const stateContent = readStateFile(projectDir);
  const scope = getField(stateContent, "Scope") || "";
  const graph: RuntimeGraph = {
    workflow_id: "",
    scope,
    started_at: "",
    stages: [],
  };
  withAuditLock(projectDir, () => {
    writeFileAtomic(runtimeGraphPath(projectDir), JSON.stringify(graph, null, 2) + "\n");
  });
  return { written: runtimeGraphPath(projectDir) };
}

// --- Read subcommand ---

function readStage(stageSlug: string, projectDir: string): RuntimeStage | null {
  const path = runtimeGraphPath(projectDir);
  if (!existsSync(path)) return null;
  const raw = readFileSync(path, "utf-8");
  const graph: RuntimeGraph = JSON.parse(raw);
  return graph.stages.find((s) => s.stage_slug === stageSlug) || null;
}

// --- CLI ---

function printHelp(): void {
  console.log(`Usage: aidlc-runtime <subcommand>

Subcommands:
  compile [--test-run]      Walk audit + memory, write runtime-graph.json
  read <stage-slug>         Print one stage row from runtime-graph.json
  --help, -h                Show this message

The compile subcommand is invoked automatically by the PostToolUse Bash
hook (aidlc-runtime-compile.ts) on every transition-class audit emit.
Manual invocation is a debug surface.`);
}

async function main(): Promise<void> {
  const [cmd, ...args] = process.argv.slice(2);
  if (cmd === "--help" || cmd === "-h") {
    printHelp();
    return;
  }
  if (cmd === undefined) {
    process.stderr.write(
      "Usage: aidlc-runtime <subcommand>. Valid: compile, read. Run with --help for detail.\n"
    );
    process.exit(1);
  }

  const projectDir = resolveProjectDir();

  if (cmd === "compile") {
    const testRun = args.includes("--test-run");
    try {
      const result = compile({ testRun, projectDir });
      if (result.skipped) {
        process.exit(0);
      }
      console.log(JSON.stringify(result));
    } catch (err) {
      process.stderr.write(`aidlc-runtime compile: ${(err as Error).message}\n`);
      process.exit(1);
    }
    return;
  }

  if (cmd === "read") {
    const stageSlug = args[0];
    if (!stageSlug) {
      process.stderr.write("aidlc-runtime read: stage slug required\n");
      process.exit(1);
    }
    const row = readStage(stageSlug, projectDir);
    if (!row) {
      process.stderr.write(`aidlc-runtime read: no row for slug "${stageSlug}"\n`);
      process.exit(1);
    }
    console.log(JSON.stringify(row, null, 2));
    return;
  }

  process.stderr.write(`Unknown subcommand: ${cmd}. Run aidlc-runtime --help for usage.\n`);
  process.exit(1);
}

if (import.meta.main) void main();
