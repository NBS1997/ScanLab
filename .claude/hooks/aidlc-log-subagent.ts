// SubagentStop hook: Emit SUBAGENT_COMPLETED when a subagent finishes.
// Replaces the previous free-form `## Subagent Completed` markdown write with
// a canonical audit event.
//
// Receives JSON on stdin with subagent info. No-op if no audit.md exists.
import { existsSync, mkdirSync, writeFileSync } from "fs";
import { join } from "path";
import {
  resolveProjectDirFromHook,
  auditFilePath,
  isoTimestamp,
  recordHookDrop,
} from "../tools/aidlc-lib.ts";
import { appendAuditEntry } from "../tools/aidlc-audit.ts";

const projectDir = resolveProjectDirFromHook(import.meta.url);

// Write health heartbeat
const healthDir = join(projectDir, "aidlc-docs", ".aidlc-hooks-health");
mkdirSync(healthDir, { recursive: true });
writeFileSync(join(healthDir, "log-subagent.last"), isoTimestamp(), "utf-8");

// Read JSON from stdin. Exit cleanly if stdin is a TTY (no Claude Code JSON
// coming) — avoids blocking on terminal read in test / debug-mode contexts.
if (process.stdin.isTTY) process.exit(0);

const input = await Bun.stdin.text();
let parsed: any;
try {
  parsed = JSON.parse(input);
} catch {
  process.exit(0);
}

const agentType = parsed?.agent_type ?? "unknown";
const agentId: string = parsed?.agent_id ?? "";
const agentMessage: string = (parsed?.last_assistant_message ?? "").slice(0, 200);

const auditFile = auditFilePath(projectDir);
if (!existsSync(auditFile)) process.exit(0);

const fields: Record<string, string> = {
  "Agent Type": agentType,
};
if (agentId) fields["Agent ID"] = agentId;
if (agentMessage) fields["Message"] = agentMessage;

try {
  appendAuditEntry("SUBAGENT_COMPLETED", fields, projectDir);
} catch (e: any) {
  recordHookDrop(projectDir, "log-subagent", e?.message ?? "unknown");
  process.exit(0);
}
