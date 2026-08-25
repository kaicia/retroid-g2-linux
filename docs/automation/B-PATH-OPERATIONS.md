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

A task is not considered complete until the matching OpenCode Run, job/log result, and actual repository result have been checked.

## Human-in-the-loop operating rule

1. Review current GitHub state and select exactly one next task.
2. Submit exactly one B-path request.
3. Verify the bridge run and immediately obtain the OpenCode Run ID.
4. Report the Task ID, Request ID, bridge Run ID, and OpenCode Run ID.
5. Do not launch another development task while waiting.
6. The project owner later asks for a status check.
7. Re-check the exact OpenCode Run ID and its Job/log state.
8. If running, report running and wait.
9. If failed, diagnose and repair before resuming.
10. If successful, inspect branch/commit/diff/PR and only then select the next task.

## Completion rules

Complete means all relevant evidence points to the same task:

- matching `task_id` / `request_id`;
- matching bridge Run;
- matching OpenCode `workflow_dispatch` Run;
- successful OpenCode job/logs;
- actual changed files and commit when code work was requested;
- PR when a PR is required by the task.

A stale Run, a similar-looking comment, or a successful test run is never sufficient.

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
