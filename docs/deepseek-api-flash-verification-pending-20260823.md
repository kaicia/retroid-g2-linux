# DeepSeek API Flash verification status

The OpenCode workflow on `main` is configured to use the official DeepSeek API with `DEEPSEEK_API_KEY` and to select `deepseek/deepseek-v4-flash` for ordinary `/oc` comments. A Pro escalation is selected only for `/oc-pro`, `/opencode-pro`, or `[pro]`.

As of 2026-08-23, the latest visible Issue #4 `/oc` verification comment has not yet produced a corresponding new Actions/OpenCode bot result in the GitHub connector. The only visible completed OpenCode run is the older 2026-08-22 run, whose logs explicitly show OpenRouter and `cohere/north-mini-code:free`; it is not evidence for the new DeepSeek direct-API configuration.

Do not mark Flash verification successful until a post-migration Actions run proves the new provider/model path and the DeepSeek usage dashboard shows a non-zero request/token/cost change.
