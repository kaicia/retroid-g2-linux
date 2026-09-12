# Archived material

Documents in this directory describe project mechanisms that are **no longer
active**. They are kept as audit history because this repository is the
project's system of record. Do not follow their instructions.

## `automation/` — retired 2026-09-12

The ChatGPT → GitHub → OpenCode → DeepSeek automation loop (the "B path") was
retired when development moved to direct GitHub work by a coding agent
(Claude Code) operating on the repository.

Removed from the working tree at the same time:

- `.github/workflows/dispatch-bridge.yml` — push-triggered `workflow_dispatch` bridge
- `.github/workflows/opencode.yml` — OpenCode + DeepSeek execution workflow
- `.github/workflows/g2-actions-probe.yml` — runner connectivity probe
- `dispatch/` — `request.json`, `response.json`, `smoke-test.json`, `compile-task.txt`

The current development workflow is `docs/development-workflow.md`.

### What these documents still explain

They remain useful for understanding *why* certain rules exist, and several of
those rules were carried forward into the new workflow:

- `incident-20260828-stale-dispatch-misattribution.md` — why evidence must match
  the exact request that produced it. The general principle (never present an
  older result as the current one) still applies.
- `B-PATH-OPERATIONS.md` — the G2 safety rules it lists (no internal
  Android/UFS/ABL/GPT/boot/vendor_boot/vbmeta/dtbo modification, build-side
  validation first, microSD-only objective) are unchanged and are restated in
  the current workflow document.
- `deepseek-compile-task-20260827.md` — the DTB compile task it specifies was
  never executed. It is carried forward as outstanding work in
  `docs/development-workflow.md`.

### Repository secrets and branches

Retiring the workflows does not revoke credentials. The following are no longer
used by any workflow in this repository and can be deleted in GitHub settings:

- `DEEPSEEK_API_KEY`
- `WORKFLOW_DISPATCH_TOKEN`

The `automation/status`, `automation/phase-c-run`, `opencode/*` and `codex-*`
remote branches are likewise inert. They are left in place; delete them only
deliberately.
