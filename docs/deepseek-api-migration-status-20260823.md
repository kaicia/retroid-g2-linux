# DeepSeek API migration status — 2026-08-23

## Decision
Preserve the existing OpenCode GitHub Actions automation loop. Replace only the LLM provider/model configuration used by that loop.

Existing loop retained:
`issue_comment /oc` → GitHub Actions → `anomalyco/opencode/github@latest` → repository work → commit/branch/PR → OpenCode result comment → external review.

## Current provider
- API provider: official DeepSeek API
- Secret: `DEEPSEEK_API_KEY`
- Default model: `deepseek/deepseek-v4-flash`
- OpenRouter is no longer used by the active workflow.

## Important validation rule
Do not treat an old OpenRouter Actions run as evidence of DeepSeek operation. A valid migration test must be a new run from the current workflow and must verify the actual OpenCode provider/model in its logs. DeepSeek usage should also increase after a successful API call.

## Model policy
Flash is the normal/default model. Pro is reserved for genuinely difficult kernel/DTS reasoning, difficult build failures, subtle driver-porting issues, or when Flash fails/produces an uncertain result. Pro escalation must be implemented only after the basic Flash path is verified.

## Project safety boundary
The G2 project remains microSD-only. Internal Android/UFS/boot/vbmeta/dtbo/ABL storage must not be modified. Removing microSD must preserve stock Android boot.

## Status
The active workflow has been reduced to the original automation structure with DeepSeek Flash as the provider/model replacement. The next verification is a fresh `/oc` execution against this current workflow, followed by inspection of the new Actions run and OpenCode logs. G2 implementation work remains paused until that verification succeeds.
