#!/usr/bin/env bash
# SessionStart check for codex-harness. Prints nothing when Codex is ready.
# If the Codex CLI is missing or logged out, it shows the user a one-line notice and
# tells Claude, so a request to "use Codex" leads to setup instead of a failed run.
# It only runs local commands (`command -v codex`, `codex login status`): no network.

problem=""
fix=""
if ! command -v codex >/dev/null 2>&1; then
  problem="the Codex CLI is not installed"
  fix="npm i -g @openai/codex, then codex login"
elif [ -z "${CODEX_API_KEY:-}" ] && [ -z "${OPENAI_API_KEY:-}" ] \
     && ! codex login status >/dev/null 2>&1; then
  problem="Codex is not logged in"
  fix="codex login"
fi

[ -n "$problem" ] || exit 0

notice="codex-harness: $problem. Run /codex-harness:setup, or in a terminal: $fix"
context="codex-harness setup is incomplete: $problem, so Codex asset generation will fail until it is fixed. If the user asks for anything that uses Codex, first tell them this and offer to run the codex-harness setup skill (/codex-harness:setup)."

# Both strings are fixed text above with no quotes or backslashes, so they are safe in JSON as-is.
printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' \
  "$notice" "$context"
