// aidlc-guardrail.ts — Guardrail emission + self-learning loop helper
//
// Two commands:
//   trigger — emit GUARDRAIL_TRIGGERED when a guardrail blocks agent behavior
//   learn  — emit GUARDRAIL_LEARNED when a human correction becomes a persistent
//            rule, and append that rule to the relevant guardrails.md file
//
// Writes to:
//   aidlc-claude-code/.claude/rules/aidlc-project.md (by default)
//   aidlc-claude-code/.claude/rules/aidlc-org.md (with --scope org)

import { resolveProjectDir, emitError } from "./aidlc-lib.js";
import { appendAuditEntry } from "./aidlc-audit.ts";
import { readFileSync, writeFileSync, existsSync } from "fs";
import { join } from "path";

// --- Audit emission helper ---

function emitAudit(
  pd: string,
  eventType: string,
  fields: Record<string, string>
): void {
  appendAuditEntry(eventType, fields, pd);
}

// --- Locate guardrails file ---
// Guardrails live at <project>/.claude/rules/ inside the user's project —
// NOT the framework source tree. Resolve via projectDir so multi-project
// installations don't clobber a shared file.

function guardrailsFilePath(pd: string, scope: "project" | "org"): string {
  const filename = scope === "org" ? "aidlc-org.md" : "aidlc-project.md";
  return join(pd, ".claude", "rules", filename);
}

// --- Flag parsing ---

function parseFlags(args: string[]): Record<string, string> {
  const flags: Record<string, string> = {};
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (!a.startsWith("--")) continue;
    if (i + 1 >= args.length) {
      error(`${a} expects a value, got end of arguments.`);
    }
    const val = args[i + 1];
    if (val.startsWith("--")) {
      error(`${a} expects a value, got another flag: "${val}". Did you forget the value?`);
    }
    flags[a.slice(2)] = val;
    i++;
  }
  return flags;
}

// --- Subcommand: trigger ---
// Usage: aidlc-guardrail trigger --rule <text> --action <blocked-action>
//
// Fires when a guardrail blocks agent behavior (e.g., agent about to re-ask
// a question already answered in an earlier stage).
function handleTrigger(args: string[]): void {
  const flags = parseFlags(args);
  if (!flags.rule) error("Missing --rule <text>");
  if (!flags.action) error("Missing --action <blocked-action>");

  const pd = resolveProjectDir(projectDir);

  try {
    emitAudit(pd, "GUARDRAIL_TRIGGERED", {
      Rule: flags.rule,
      Action: flags.action,
    });
  } catch (e: any) {
    error(`Audit emission failed: ${e.message}`);
  }

  console.log(
    JSON.stringify({ emitted: "GUARDRAIL_TRIGGERED", rule: flags.rule, action: flags.action })
  );
}

// --- Subcommand: learn ---
// Usage: aidlc-guardrail learn --correction <text> --rule <new-rule> [--scope project|org] [--section <heading>]
//
// Records a human correction as a new persistent guardrail. Emits
// GUARDRAIL_LEARNED and appends the rule to the appropriate guardrails.md.
// --scope defaults to "project"; --section defaults to "Corrections".
function handleLearn(args: string[]): void {
  const flags = parseFlags(args);
  if (!flags.correction) error("Missing --correction <text>");
  if (!flags.rule) error("Missing --rule <new-rule>");

  const scope = (flags.scope || "project") as "project" | "org";
  if (!["project", "org"].includes(scope)) {
    error(`Invalid --scope: ${scope}. Must be 'project' or 'org'.`);
  }
  const section = flags.section || "Corrections";

  const pd = resolveProjectDir(projectDir);
  const guardrailsPath = guardrailsFilePath(pd, scope);
  if (!existsSync(guardrailsPath)) {
    error(`Guardrails file not found: ${guardrailsPath}`);
  }

  // Validate file shape BEFORE emitting audit. If the section heading is
  // missing we must NOT leave an orphan GUARDRAIL_LEARNED in audit.md with
  // no corresponding rule in guardrails.md (audit-first atomicity).
  const content = readFileSync(guardrailsPath, "utf-8");
  const sectionHeading = `## ${section}`;
  const idx = content.indexOf(sectionHeading);
  if (idx === -1) {
    error(`Section not found in ${guardrailsPath}: '${sectionHeading}'`);
  }
  const lineEnd = content.indexOf("\n", idx);
  if (lineEnd === -1) {
    error(`Malformed guardrails file: no newline after ${sectionHeading}`);
  }

  // Emit audit FIRST now that all file-level preconditions hold.
  try {
    emitAudit(pd, "GUARDRAIL_LEARNED", {
      Correction: flags.correction,
      "Guardrail added": flags.rule,
      Scope: scope,
      Section: section,
    });
  } catch (e: any) {
    error(`Audit emission failed: ${e.message}`);
  }

  // Append to guardrails file
  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
  const newLine = `- ${flags.rule} (learned ${today})`;
  const updatedContent =
    content.slice(0, lineEnd + 1) + newLine + "\n" + content.slice(lineEnd + 1);

  writeFileSync(guardrailsPath, updatedContent, "utf-8");

  console.log(
    JSON.stringify({
      emitted: "GUARDRAIL_LEARNED",
      scope,
      section,
      rule: flags.rule,
      file: guardrailsPath,
    })
  );
}

// --- CLI entry point ---

let projectDir: string | undefined;

function main(): void {
  const rawArgs = process.argv.slice(2);

  const filteredArgs: string[] = [];
  for (let i = 0; i < rawArgs.length; i++) {
    if (rawArgs[i] === "--project-dir" && i + 1 < rawArgs.length) {
      projectDir = rawArgs[i + 1];
      i++;
    } else {
      filteredArgs.push(rawArgs[i]);
    }
  }

  const subcommand = filteredArgs[0];

  try {
    switch (subcommand) {
      case "trigger":
        handleTrigger(filteredArgs.slice(1));
        break;
      case "learn":
        handleLearn(filteredArgs.slice(1));
        break;
      default:
        error(`Unknown subcommand: ${subcommand}. Valid: trigger, learn`);
    }
  } catch (e: any) {
    error(e.message);
  }
}

function error(msg: string): never {
  const pd = resolveProjectDir(projectDir);
  const command = `aidlc-guardrail ${process.argv.slice(2).join(" ")}`.trim();
  emitError(pd, "aidlc-guardrail", command, msg);
}

if (import.meta.main) {
  main();
}
