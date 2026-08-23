# OpenCode → DeepSeek Direct API Migration

Date: 2026-08-23

## Decision
The repository no longer routes OpenCode through the OpenRouter free model. The GitHub Actions workflow now uses the native DeepSeek provider in OpenCode with `deepseek/deepseek-v4-pro` and the `DEEPSEEK_API_KEY` GitHub Actions secret.

## Reason
The previous OpenRouter free model was subject to daily usage limits and could stop the autonomous coding workflow. A direct paid DeepSeek API removes that specific free-model quota dependency.

## Official compatibility
OpenCode officially lists DeepSeek as a provider and supports connecting a DeepSeek API key. DeepSeek's own integration guide explicitly supports OpenCode and recommends DeepSeek V4 Pro. The DeepSeek API is OpenAI/Anthropic compatible.

## Required repository secret
`DEEPSEEK_API_KEY` must exist as a GitHub Actions secret. The secret value must never be committed to the repository or placed in workflow source.

## Current workflow
`.github/workflows/opencode.yml`
- OpenCode GitHub Action
- `DEEPSEEK_API_KEY` environment variable
- model: `deepseek/deepseek-v4-pro`
- GitHub token retained for repository/PR operations

## Safety/project rules unchanged
- G2 internal Android/UFS storage remains untouched.
- No internal boot/AVB/GPT/partition flashing.
- First Linux artifacts remain microSD-only.
- Removing microSD must preserve the stock Android boot path.

## Validation plan
Trigger the existing G2 Stage 0 Issue with `/oc` after the API secret is available. Confirm the workflow can authenticate to DeepSeek, OpenCode executes the task, and a branch/commit/PR is produced. If it fails, inspect the Actions job logs before retrying.
