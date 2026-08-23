# OpenCode → DeepSeek Direct API Migration

Date: 2026-08-23

## Decision
OpenCode no longer routes through the OpenRouter free model. The GitHub Actions workflow uses the native DeepSeek provider with the `DEEPSEEK_API_KEY` GitHub Actions secret.

## Model routing policy
- **Default:** `deepseek/deepseek-v4-flash` for routine repository inspection, documentation, straightforward coding, normal DTS work, and ordinary fixes.
- **Escalation:** `deepseek/deepseek-v4-pro` only for genuinely difficult kernel/DTS dependency reasoning, difficult build failures, subtle driver-porting work, or when Flash fails or produces an uncertain result.
- Manual Pro escalation is requested in a GitHub comment with `/oc-pro`, `/opencode-pro`, or `[pro]`.
- Normal `/oc` and `/opencode` comments use Flash.

## Reason
The previous OpenRouter free model was subject to daily usage limits and could stop the autonomous coding workflow. Direct paid DeepSeek API removes that specific free-model quota dependency while keeping OpenCode as the coding agent.

## Required repository secret
`DEEPSEEK_API_KEY` must exist as a GitHub Actions secret. The secret value must never be committed to the repository or placed in workflow source.

## Current workflow
`.github/workflows/opencode.yml`
- OpenCode GitHub Action
- `DEEPSEEK_API_KEY` environment variable
- Flash default
- explicit Pro escalation via comment marker
- GitHub token retained for repository/PR operations

## Safety/project rules unchanged
- G2 internal Android/UFS storage remains untouched.
- No internal boot/AVB/GPT/partition flashing.
- First Linux artifacts remain microSD-only.
- Removing microSD must preserve the stock Android boot path.

## Validation plan
After the `DEEPSEEK_API_KEY` secret is available, trigger the existing G2 Stage 0 Issue with `/oc`. Confirm authentication, OpenCode execution, and branch/commit/PR creation. Separately test `/oc-pro` only when a Pro escalation is needed. If a run fails, inspect Actions logs before retrying.
