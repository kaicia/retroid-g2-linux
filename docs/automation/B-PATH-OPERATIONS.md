# B Path — Production Development Loop

## Purpose

This is the production GitHub-centred development path for the Retroid Pocket G2 SteamOS-class project. It is separate from the historical `/oc` comment path, which remains available as a compatibility/fallback path.

## Task request format

Every real development request is exactly one task and carries a unique `task_id`.

Recommended format:

```json
{
  "task_id": "G2-C-0001",
  "request_id": "G2-C-0001-R1",
  "ref": "main",
  "model": "deepseek/deepseek-v4-flash",
  "prompt": "Perform exactly this one G2 development task..."
}
```

Rules:

- `task_id` identifies the development task across retries and verification.
- `request_id` identifies one dispatch request/attempt.
- `ref` is normally `main` unless the task explicitly requires another ref.
- `model` defaults to official DeepSeek V4-Flash. Use V4-Pro only for a justified escalation.
- `prompt` must describe one concrete task, its evidence requirements, safety limits, and expected deliverable.
- A real task must not use historical test identifiers such as `B-TEST-*`.

## Execution identity chain

The exact identity chain is mandatory:

```text
Task ID
  → Request ID
  → bridge Actions Run ID
  → workflow_dispatch OpenCode Run ID
  → OpenCode Job ID
  → DeepSeek model/provider
  → branch
  → commit SHA
  → completion/result comment ID (when used)
  → PR number/URL
```

A task is not considered started until the bridge has produced a real OpenCode `workflow_dispatch` Run ID.

## Human-in-the-loop operating rule

1. Review current GitHub state and select exactly one next task.
2. Submit exactly one B-path request.
3. Verify the bridge run and immediately obtain the OpenCode Run ID.
4. Report the Task ID, Request ID, bridge Run ID, and OpenCode Run ID.
5. Do not launch another development task while waiting.
6. The project owner later asks for a status check.
7. Re-check the exact OpenCode Run ID and its Job/log state.
8. **Always read the matching live trace file before interpreting progress or completion:** `dispatch/trace/<request_id>.json` on `automation/status` (or its explicitly recorded replacement for a rerun).
9. Compare the trace's `updated_at`, `state`, `phase`, `last_activity`, `last_output`, and `tool_trace` with the Actions job/log state. Never rely on the Actions job state alone.
10. If running, report running and wait.
11. If failed, diagnose and repair before resuming.
12. If successful, inspect branch/commit/diff/PR and only then select the next task.

## Mandatory status-check checklist

Whenever the project owner asks for a status check (`확인해`, `확인`, or equivalent), the assistant must perform these checks in order:

1. Exact Task ID / Request ID.
2. Exact Actions Run ID and latest Job ID.
3. **Matching live trace file**, including latest `updated_at`, `state`, `phase`, `last_activity`, `last_output`, and `tool_trace`.
4. Current OpenCode/DeepSeek provider and model when visible.
5. Actual job steps/logs.
6. On completion: branch, commit SHA, changed files, report, artifacts, PR and CI/status checks.
7. Only after all relevant evidence agrees, declare success/failure and choose the next task.

A trace file is evidence, not a substitute for the Actions/job result; both must agree before completion is declared.

## Retry / Rerun identity rule

A GitHub Actions job rerun must receive a **new logical Request ID** even when GitHub keeps the same workflow `run_id` and creates a new Job ID. The original request and trace file must remain immutable historical evidence.

For example:

```text
G2-B-0001-R1 → original request / original trace
G2-B-0001-R2 → rerun request / separate trace
```

The R2 trace must record the underlying GitHub workflow `run_id`, the new Job ID, and `rerun_of: G2-B-0001-R1` when the same workflow run is reused. Never overwrite R1 with R2 data.

If the automation currently reuses the old trace path during a rerun, record that as a trace-integrity defect and repair it before the next real development task. Preserve the old trace and create the corrected R2 record from the verified run/job evidence.

## Completion rules

Complete means all relevant evidence points to the same task:

- matching `task_id` / `request_id`;
- matching bridge Run;
- matching OpenCode `workflow_dispatch` Run;
- successful OpenCode job/logs;
- matching live trace state and timestamps;
- actual changed files and commit when code work was requested;
- PR when a PR is required by the task.

A stale Run, a similar-looking comment, a trace from another request, or a successful test run is never sufficient.

## Failure rules

- Never relabel an old successful run as the current task.
- Never start a duplicate task merely because the current task has not been checked recently.
- Fix the automation or task blocker first when the current execution fails.
- If OpenCode leaves a changed branch without a PR, the configured deterministic PR fallback may recover it; record that as a fallback event.

## Safety rules for G2

The default development loop is non-destructive to the physical device.

- No internal Android/UFS/ABL/GPT/boot/vendor_boot/vbmeta/dtbo modification.
- No physical G2 flashing unless a separately approved hardware-test task explicitly requires it.
- Build-side validation and removable-media artifacts come first.
- Every real task must preserve the reversible microSD-only objective.
