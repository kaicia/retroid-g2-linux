# GitHub-Centred Development Loop

This directory contains the active automation design and operational checks for the G2 project.

The authoritative rebuild protocol is `docs/project-rebuild-20260825.md`.

The active development rule is human-in-the-loop:

1. submit exactly one development task;
2. record its exact execution identifier;
3. wait for the project owner to request a status check;
4. trace that exact task through Actions/OpenCode/DeepSeek;
5. if complete, review the actual PR/diff and choose the next task;
6. if still running, report waiting;
7. if failed, repair the automation or task before continuing.

Historical connectivity/permission tests are not development evidence.
