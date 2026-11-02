#!/usr/bin/env bash
# codex-gen.sh - ask the OpenAI Codex CLI to write ONE markdown asset.
#
# Usage (run from the project root; the brief comes on stdin):
#   codex-gen.sh <out.md> [--ref <file>]... [--overwrite] [--model <m>] [--effort <level>] <<'BRIEF'
#   ...what to generate...
#   BRIEF
#
# Codex runs in a read-only sandbox: it can read the project for context but cannot
# change anything. Its final answer is captured and written to <out.md> by this
# script, so every call produces exactly one markdown file and touches nothing else.
#
# Env: CODEX_HARNESS_MODEL, CODEX_HARNESS_EFFORT, CODEX_HARNESS_TIMEOUT (seconds, default 600)

set -euo pipefail

die() { echo "codex-gen: $*" >&2; exit 1; }
usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-1}"; }
# Git Bash on Windows: hand native Windows paths to codex.exe.
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

# Recursion guard: never let a Codex run start another harness call.
[ -z "${CODEX_HARNESS_ACTIVE:-}" ] || die "refusing to run inside another codex-gen call (recursion guard)"
export CODEX_HARNESS_ACTIVE=1

out=""; overwrite=0
refs=()
model="${CODEX_HARNESS_MODEL:-}"
effort="${CODEX_HARNESS_EFFORT:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --ref)       [ $# -ge 2 ] || die "--ref needs a path"; refs+=("${2//\\//}"); shift 2 ;;
    --overwrite) overwrite=1; shift ;;
    -m|--model)  [ $# -ge 2 ] || die "--model needs a value"; model="$2"; shift 2 ;;
    --effort)    [ $# -ge 2 ] || die "--effort needs a value"; effort="$2"; shift 2 ;;
    -h|--help)   usage 0 ;;
    -*)          die "unknown option: $1 (see --help)" ;;
    *)           [ -z "$out" ] || die "one output file per call (got '$out' and '$1')"; out="${1//\\//}"; shift ;;
  esac
done

[ -n "$out" ] || usage 1

# --- validate the output path -------------------------------------------------
case "$out" in
  *.md|*.MD|*.markdown) ;;
  *) die "output must be a markdown file (.md): $out" ;;
esac
case "$out" in
  /*|[A-Za-z]:*) die "output path must be relative to the project root: $out" ;;
esac
case "/$out/" in
  */../*) die "output path may not contain '..': $out" ;;
esac
if [ -e "$out" ] && [ "$overwrite" -eq 0 ]; then
  die "$out already exists. To revise it, pass --ref $out --overwrite; otherwise pick another name."
fi
[ ! -d "$out" ] || die "$out is a directory"

# Reference files are pasted into the prompt instead of being read by Codex itself:
# Codex's sandbox can't always run commands (e.g. a missing helper on Windows), and
# then it may guess the contents. Inlining makes the context the same on every OS.
max_ref_kb="${CODEX_HARNESS_MAX_REF_KB:-400}"
total_bytes=0
for r in ${refs[@]+"${refs[@]}"}; do
  [ -f "$r" ] || die "--ref not found (or not a file): $r"
  [ ! -s "$r" ] || grep -Iq . "$r" || die "--ref is not a text file: $r"
  total_bytes=$(( total_bytes + $(wc -c < "$r") ))
done
[ "$total_bytes" -le $(( max_ref_kb * 1024 )) ] \
  || die "--ref files total $(( total_bytes / 1024 )) KB, over the ${max_ref_kb} KB limit. Pass smaller files or excerpts (or raise CODEX_HARNESS_MAX_REF_KB)."

command -v codex >/dev/null 2>&1 || die "codex CLI not found on PATH. Install it with 'npm i -g @openai/codex', then run 'codex login'."

# --- read the brief -------------------------------------------------------------
if [ -t 0 ]; then die "no brief given: pipe it on stdin (heredoc)"; fi
brief="$(cat)"
[ -n "${brief//[[:space:]]/}" ] || die "the brief on stdin is empty"

root="$(pwd)"
tmp="$(mktemp -d 2>/dev/null || mktemp -d -t codexgen)"
trap 'rm -rf "$tmp"' EXIT

# --- build the prompt -----------------------------------------------------------
{
  echo "You are writing ONE written asset for a software project. Another AI coding agent"
  echo "(Claude Code) working in this repository delegated it to you."
  echo
  echo "## Brief"
  echo
  printf '%s\n' "$brief"
  echo
  echo "## Context"
  echo
  echo "- Project root: $(native "$root")"
  echo "- Your answer will be saved as: $out"
  if [ ${#refs[@]} -gt 0 ]; then
    echo "- The reference files below are the source of truth. Follow them exactly."
  fi
  for r in ${refs[@]+"${refs[@]}"}; do
    echo
    echo "### Reference file: $r"
    echo
    echo "<<<<<<<< BEGIN $r"
    tr -d '\r' < "$r"
    echo
    echo ">>>>>>>> END $r"
  done
  if [ -f CODEX_STYLE.md ]; then
    echo
    echo "## Project style guide (CODEX_STYLE.md - follow it)"
    echo
    cat CODEX_STYLE.md
    echo
  fi
  echo
  echo "## Output contract (follow exactly)"
  echo
  echo "- Your final message IS the file. It is written verbatim to $out."
  echo "- Reply with GitHub-flavored Markdown only. No preamble like \"Here is...\", no sign-off,"
  echo "  and do not wrap the whole answer in a code fence."
  echo "- Unless the brief says otherwise, start with a level-1 heading."
  echo "- You are in a read-only sandbox: do not try to create or edit files. Everything essential"
  echo "  is included above. You may read other project files if your tools work, but never guess"
  echo "  what a file says: if you could not read it, do not rely on it."
  echo "- Nobody can answer questions. If something is ambiguous, make a sensible choice and keep going."
  echo "- Make it complete and directly usable: no TODOs or placeholder text unless the brief asks for them."
} > "$tmp/prompt.md"

# --- run codex ------------------------------------------------------------------
args=(exec --sandbox read-only --skip-git-repo-check --ephemeral --color never
      -C "$(native "$root")" -o "$(native "$tmp/last.md")")
[ -z "$model" ]  || args+=(-m "$model")
[ -z "$effort" ] || args+=(-c "model_reasoning_effort=$effort")
args+=(-)

# Only GNU timeout: on Windows a bare `timeout` can resolve to the unrelated timeout.exe.
runner=()
if timeout --version 2>/dev/null | grep -q coreutils; then
  runner=(timeout "${CODEX_HARNESS_TIMEOUT:-600}")
fi

start=$(date +%s)
set +e
${runner[@]+"${runner[@]}"} codex "${args[@]}" < "$tmp/prompt.md" > "$tmp/codex.log" 2>&1
status=$?
set -e
elapsed=$(( $(date +%s) - start ))
[ -z "${CODEX_HARNESS_LOG:-}" ] || cp "$tmp/codex.log" "$CODEX_HARNESS_LOG"

if [ "$status" -ne 0 ]; then
  [ "$status" -ne 124 ] || echo "codex-gen: codex timed out after ${CODEX_HARNESS_TIMEOUT:-600}s" >&2
  echo "codex-gen: codex exec failed (exit $status). Last lines of its output:" >&2
  tail -n 40 "$tmp/codex.log" >&2
  exit 1
fi
if [ ! -s "$tmp/last.md" ]; then
  echo "codex-gen: codex finished but returned no answer. Last lines of its output:" >&2
  tail -n 40 "$tmp/codex.log" >&2
  exit 1
fi

# --- clean up and save ----------------------------------------------------------
# Drop CRs, and unwrap the answer if Codex fenced the whole thing in ```markdown ... ```.
tr -d '\r' < "$tmp/last.md" | awk '
  { line[NR] = $0 }
  END {
    first = 1; while (first <= NR && line[first] ~ /^[[:space:]]*$/) first++
    last = NR;  while (last >= first && line[last] ~ /^[[:space:]]*$/) last--
    if (last > first && line[first] ~ /^```(markdown|md)?[[:space:]]*$/ && line[last] ~ /^```[[:space:]]*$/) {
      first++; last--
    }
    for (i = first; i <= last; i++) print line[i]
  }' > "$tmp/clean.md"

[ -s "$tmp/clean.md" ] || die "codex returned only whitespace; nothing written"

mkdir -p "$(dirname "$out")"
cp "$tmp/clean.md" "$out"

lines=$(wc -l < "$out" | tr -d ' ')
bytes=$(wc -c < "$out" | tr -d ' ')
echo "codex-gen: wrote $out ($lines lines, $bytes bytes) in ${elapsed}s"
