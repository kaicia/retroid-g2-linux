# GitHub-Centred Development Loop

This directory contains the active automation design and operational checks for the G2 project.

The authoritative rebuild protocol is `docs/project-rebuild-20260825.md`.

The production execution path is documented in `docs/automation/B-PATH-OPERATIONS.md`.

## Active development rule

The loop is human-in-the-loop:

1. inspect the current repository state;
2. define exactly one development task;
3. submit one B-path request with a unique Task ID and Request ID;
4. immediately verify that the bridge created the matching OpenCode `workflow_dispatch` Run ID;
5. report those exact identifiers and wait;
6. only when the project owner requests a status check, trace that exact Run through Actions/OpenCode/DeepSeek;
7. if complete, inspect the actual branch/commit/diff/PR and choose the next task;
8. if still running, report waiting;
9. if failed, repair the automation or task before continuing.

Historical connectivity/permission tests are not development evidence. The existing `/oc` comment path remains available but is not the default B-path execution mechanism.
