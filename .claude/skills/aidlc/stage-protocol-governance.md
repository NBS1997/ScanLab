# Stage Protocol: Guardrail Learning & Phase Boundary Verification

Load this file at phase transitions (end of Ideation, Inception, Construction). Note: The Initialization→Ideation transition has no governance boundary check.
This is also loaded when a user correction triggers a guardrail candidate.
This is a supplement to `stage-protocol.md` — the main protocol still applies.

---

## 12. Guardrail Learning Protocol

When a human corrects agent behavior during any stage, the correction may warrant a persistent guardrail.

### Correction → Guardrail flow
1. **Detect correction**: Human says "don't do X", "always do Y", or provides feedback that implies a behavioral rule
2. **Classify scope**:
   - **Project-specific** → propose adding to `.claude/rules/aidlc-project.md`
   - **Organization-wide** → propose adding to `.claude/rules/aidlc-org.md`
3. **Propose the guardrail**: Present the exact text to the user for approval:
   ```
   I noticed a correction that could become a persistent guardrail:
   NEVER/ALWAYS [behavior] (learned [date])

   Should I add this to [project/org] guardrails?
   ```
4. **If approved**: Append the guardrail to the appropriate file under the Corrections section
5. **Log the event**: Append a GUARDRAIL_LEARNED entry to `aidlc-docs/audit.md` via Bash `cat >>`

### Conflict detection
Before proposing a new guardrail, scan both guardrail files (`.claude/rules/aidlc-org.md` and `.claude/rules/aidlc-project.md`) for contradictions with the candidate guardrail.

If a new guardrail would contradict an existing one, present both to the user before adding:
```
This new guardrail conflicts with an existing one:
  EXISTING: [text of existing guardrail]
  NEW:      [text of proposed guardrail]
Which should take precedence, or should both be kept with a scope distinction?
```

Resolution options:
- **Replace**: Remove the existing guardrail and add the new one
- **Keep both with scope**: Retain both but annotate each with the scope in which it applies (e.g., org-wide vs. this project only)
- **Discard new**: Keep the existing guardrail unchanged

Log the conflict and resolution to `aidlc-docs/audit.md` using the standard audit log format.

### Periodic review prompt
At the start of every new Ideation phase (stage 1.1 — Intent Capture (intent-capture)), check both guardrail files for existing entries. If either file contains any entries (non-empty Corrections, Decided, Forbidden, or Mandated sections), display:

```
You have [N] guardrails from previous sessions.
  Run `/aidlc --status` to review them, or say 'review guardrails' to see them now.
  Proceeding with current guardrails.
```

This prompt is **non-blocking** — the user can ignore it and the workflow continues automatically. If the user says "review guardrails", display all guardrail entries grouped by file (org vs. project) and section, then offer options to keep, edit, or remove each one before continuing.

### Test-Run Mode
In test-run mode (`--test-run` flag), guardrail learning is disabled — no new guardrails are proposed from corrections. Phase boundary verification still executes normally.

### Rules
- NEVER add a guardrail without explicit user approval
- Guardrails use the format: `NEVER/ALWAYS [behavior] (learned [ISO date])`
- Project guardrails also record the stage and decision: `DECIDED: [decision] (Stage [X.X], [date])`
- Both guardrail files are loaded at the start of every stage (step 1 of knowledge loading order)
- Guardrails take precedence over agent defaults when they conflict

---

## 13. Phase Boundary Verification

At each phase transition (Ideation→Inception (approval-handoff→reverse-engineering), Inception→Construction (delivery-planning→functional-design), Construction→Operation (ci-pipeline→deployment-pipeline)), run traceability verification.

### When to verify
- After the last stage of each phase is approved
- Before the first stage of the next phase begins
- On demand if the user requests verification via `/aidlc --status`

### Verification process
1. Read the verification methodology from `.claude/knowledge/aidlc-shared/verification.md`
2. Run the phase-specific traceability checks
3. Write results to `aidlc-docs/verification/[phase-boundary]-verification.md`
4. If verification fails, present issues to the user before proceeding:
   - Missing traceability links (e.g., requirement without a design)
   - Orphaned artifacts (design without a requirement)
   - Inconsistencies between phase outputs
5. Log a `PHASE_VERIFIED` event to `aidlc-docs/audit.md`

### Phase boundary checks
**Ideation → Inception**: Intent captured, scope defined, feasibility confirmed, initiative approved
**Inception → Construction**: All requirements traced to designs, units defined, delivery plan approved
**Construction → Operation**: All units built and tested, CI pipeline configured, infrastructure designed
