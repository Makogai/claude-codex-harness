---
name: setup
description: Check and set up everything the codex-harness plugin needs, which is the Codex CLI installed and logged in. Use when the user runs /codex-harness:setup, when the session-start notice says Codex is missing or logged out, or when the user asks how to get the Codex harness working.
---

# Set up codex-harness

Go through the checks below in order. Fix what you can and finish with a short checklist (✓ / ✗ per item). Keep it brief: the user wants to get back to their project.

## 1. bash

You are already running shell commands through bash, so this passes. (If you can't run bash at all on Windows, the user needs Git for Windows: https://git-scm.com/download/win.)

## 2. Codex CLI installed

Run `codex --version`.

If it's missing:

1. Check for npm: `npm --version`.
2. If npm is there, **ask the user first**, then run `npm i -g @openai/codex` (Bash timeout `300000`). Afterwards, check `codex --version` again.
   - Still "not found" after a successful install: the npm global bin folder isn't on PATH yet. Tell the user to restart their terminal and Claude Code, or to add the folder that `npm prefix -g` prints (on macOS/Linux, its `bin` subfolder) to PATH.
   - Permission errors (EACCES) on macOS/Linux: do **not** use sudo yourself. Tell the user to fix their npm prefix or use `brew install --cask codex`.
3. No npm: on macOS suggest `brew install --cask codex`. Otherwise tell them to install Node.js LTS from https://nodejs.org and run `/codex-harness:setup` again.

## 3. Codex logged in

Run `codex login status`. Exit code 0 means logged in.

If it prints "Not logged in", the login is interactive (a browser opens), so the user has to do it. Tell them to type this at the prompt:

```
! codex login
```

To use an API key instead, they can run `! codex login --with-api-key` and paste the key into **that** command's input. Never ask them to paste an API key into the chat.

Once they've finished, run `codex login status` again to confirm.

## 4. Smoke test (offer it, don't force it)

Ask whether they want a quick end-to-end test. It uses a tiny bit of their Codex quota. If yes:

```bash
codex exec --sandbox read-only --skip-git-repo-check --ephemeral --color never "Reply with exactly: codex-harness ok"
```

Pass if the output contains `codex-harness ok`. If it fails, show the last few lines of the error and stop.

## 5. Wrap up

Report the checklist. If everything passes, tell them how to use the plugin. They can just ask, for example "have Codex write 10 enemies for my game", or use `/codex-harness:asset <what to write>`. A `CODEX_STYLE.md` in the project root keeps every asset in the same voice.
