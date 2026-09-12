# Incident: stale dispatch receipt misattribution (2026-08-28)

## Summary
A completed G2-C-0002 run was temporarily misidentified as the result of a later user request.

## Evidence
- First C-0002 request commit: `88916ff2aa7cb68e7625b95d7a4e60edbc7d3fe6`, created `2026-08-28T07:46:59Z`.
- That request launched Actions Run `33152767424`, created `2026-08-28T07:47:09Z`.
- Later C-0002 re-dispatch request commit: `a473db8722a01c952dcfee4a04692b8ec8eb5c80`, created `2026-08-28T09:25:17Z`.
- The previously published `dispatch/response.json` still referenced Run `33152767424` when the later request was checked.

Therefore Run `33152767424` belonged to the earlier request and was not evidence that the later request had executed.

## Root cause
`dispatch/response.json` is a mutable receipt. After a new `dispatch/request.json` commit, the bridge may not yet have replaced the response with the new run. The verification step read the old receipt before waiting for the bridge to publish a fresh one. The old Run ID was then incorrectly treated as the current execution.

This was a verification/ordering defect, not evidence that GitHub reused an old run for a new request.

## Corrective controls
1. Never treat `dispatch/response.json` as authoritative until it matches the current request ID and task ID.
2. The response must also match the commit that introduced the current request and must have a `run_created` timestamp later than the current dispatch start.
3. Until those checks pass, do not inspect or report the returned Run/Job/trace as the current task.
4. After a request commit, wait for a fresh bridge receipt before obtaining the OpenCode Run ID.
5. Every status check must use the exact request ID and matching live trace, then compare against the Actions Job/log state.
6. A successful run with a different request timestamp or request identity is historical evidence only.

## Model/backend control
The production path remains GitHub Actions -> OpenCode -> official DeepSeek API. Codex is not the execution backend. When a specific model is requested, the actual Actions log must confirm the selected model rather than relying only on `request.json`.

## Status
This incident is resolved procedurally. The project operation rules must enforce the freshness gate before any future execution result is accepted.