#!/usr/bin/env bash
# codex-gen.sh - ask the OpenAI Codex CLI to make ONE asset file in your project.
#
#   <out>.md   a markdown document. Codex runs read-only; this script saves its answer.
#   <out>.png  an image from Codex's built-in image generation. This script moves the image
#              out of ~/.codex/generated_images and into your project at <out>.png.
#
# Usage (run from the project root; the brief comes on stdin):
#   codex-gen.sh <out.md|out.png> [--ref <file>]... [--overwrite] [--model <m>] [--effort <level>] <<'BRIEF'
#   ...what to make...
#   BRIEF
#
# --ref takes text files (pasted into the prompt) and images (.png .jpg .jpeg .webp .gif,
# attached so Codex can see them, e.g. "make a variant of this icon").
#
# Env: CODEX_HARNESS_MODEL, CODEX_HARNESS_EFFORT, CODEX_HARNESS_TIMEOUT (seconds, default 600),
#      CODEX_HARNESS_MAX_REF_KB (default 400), CODEX_HARNESS_LOG (save Codex's output there)

set -euo pipefail

die() { echo "codex-gen: $*" >&2; exit 1; }
usage() { sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-1}"; }
# Git Bash on Windows: hand native Windows paths to codex.exe, and read Windows paths back.
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
unixy()  { if command -v cygpath >/dev/null 2>&1; then cygpath -u "$1"; else printf '%s' "$1"; fi; }
is_image() { case "$1" in *.png|*.PNG|*.jpg|*.JPG|*.jpeg|*.JPEG|*.webp|*.WEBP|*.gif|*.GIF) return 0 ;; esac; return 1; }

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
  *.md|*.MD|*.markdown) mode=text ;;
  *.png|*.PNG)          mode=image ;;
  *) die "output must be a markdown document (.md) or an image (.png): $out" ;;
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

# --- reference files ------------------------------------------------------------
# Text refs are pasted into the prompt instead of being read by Codex itself: Codex's
# sandbox can't always run commands (e.g. a missing helper on Windows), and then it may
# guess the contents. Image refs are attached with `codex exec -i`.
max_ref_kb="${CODEX_HARNESS_MAX_REF_KB:-400}"
text_refs=(); image_refs=()
total_bytes=0
for r in ${refs[@]+"${refs[@]}"}; do
  [ -f "$r" ] || die "--ref not found (or not a file): $r"
  if is_image "$r"; then
    image_refs+=("$r")
  else
    [ ! -s "$r" ] || grep -Iq . "$r" || die "--ref is neither a text file nor a supported image: $r"
    text_refs+=("$r")
    total_bytes=$(( total_bytes + $(wc -c < "$r") ))
  fi
done
[ "$total_bytes" -le $(( max_ref_kb * 1024 )) ] \
  || die "text --ref files total $(( total_bytes / 1024 )) KB, over the ${max_ref_kb} KB limit. Pass smaller files or excerpts (or raise CODEX_HARNESS_MAX_REF_KB)."

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
  if [ "$mode" = image ]; then
    echo "You are making ONE image for a software project. Another AI coding agent"
  else
    echo "You are writing ONE written asset for a software project. Another AI coding agent"
  fi
  echo "(Claude Code) working in this repository delegated it to you."
  echo
  echo "## Brief"
  echo
  printf '%s\n' "$brief"
  echo
  echo "## Context"
  echo
  echo "- Project root: $(native "$root")"
  echo "- The result will be saved as: $out"
  if [ ${#text_refs[@]} -gt 0 ]; then
    echo "- The reference files below are the source of truth. Follow them exactly."
  fi
  if [ ${#image_refs[@]} -gt 0 ]; then
    echo "- Reference images are attached to this message:"
    for r in "${image_refs[@]}"; do echo "  - $r"; done
  fi
  for r in ${text_refs[@]+"${text_refs[@]}"}; do
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
  if [ "$mode" = image ]; then
    echo "## How to make it (follow exactly)"
    echo
    echo "- Use your built-in image generation tool (image_gen) to create exactly one image."
    echo "  Do not draw it with code, SVG, HTML, PIL or any other program."
    echo "- If image generation is not available to you, reply with exactly IMAGE_GEN_UNAVAILABLE and stop."
    echo "- Do not copy, move, rename or save any files yourself. The harness collects the"
    echo "  generated image automatically."
    echo "- Nobody can answer questions. If something is ambiguous, make a sensible choice and keep going."
    echo "- When the image is done, reply with one short line describing it."
  else
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
  fi
} > "$tmp/prompt.md"

# --- run codex ------------------------------------------------------------------
args=(exec)
# Image attachments first: -i takes several values, so the next flag must end the list.
for r in ${image_refs[@]+"${image_refs[@]}"}; do args+=(-i "$(native "$r")"); done
args+=(--sandbox read-only --skip-git-repo-check --color never
       -C "$(native "$root")" -o "$(native "$tmp/last.md")")
# Image mode keeps the session: its id names the folder Codex saves the image in.
[ "$mode" = image ] || args+=(--ephemeral)
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

fail() {
  echo "codex-gen: $1 Last lines of Codex's output:" >&2
  tail -n 40 "$tmp/codex.log" >&2
  exit 1
}
if [ "$status" -ne 0 ]; then
  [ "$status" -ne 124 ] || echo "codex-gen: codex timed out after ${CODEX_HARNESS_TIMEOUT:-600}s" >&2
  fail "codex exec failed (exit $status)."
fi
[ -s "$tmp/last.md" ] || fail "codex finished but returned no answer."

human_size() { awk -v b="$1" 'BEGIN { if (b >= 1048576) printf "%.1f MB", b/1048576; else if (b >= 1024) printf "%.0f KB", b/1024; else printf "%d bytes", b }'; }

# --- image mode: collect the generated image ------------------------------------
if [ "$mode" = image ]; then
  if grep -q IMAGE_GEN_UNAVAILABLE "$tmp/last.md"; then
    die "Codex says image generation is not available. It needs a ChatGPT login ('codex login status') and a current Codex version ('codex update')."
  fi
  sid="$(grep -m1 -i '^session id:' "$tmp/codex.log" | awk '{print $3}' | tr -d '\r')"
  [ -n "$sid" ] || fail "could not find the Codex session id, so the image can't be located."
  gen_dir="$(unixy "${CODEX_HOME:-$HOME/.codex}")/generated_images/$sid"
  img=""; count=0
  if [ -d "$gen_dir" ]; then
    count=$(find "$gen_dir" -maxdepth 1 -type f -name '*.png' | wc -l | tr -d ' ')
    img="$(ls -t "$gen_dir"/*.png 2>/dev/null | head -n 1 || true)"
  fi
  [ -n "$img" ] || fail "Codex finished but no generated image was found in $gen_dir. Its reply: $(head -c 300 "$tmp/last.md")"

  mkdir -p "$(dirname "$out")"
  mv -f "$img" "$out"
  rmdir "$gen_dir" 2>/dev/null || true

  # PNG width/height live in bytes 16-23 of the file.
  dims=""
  set -- $(od -An -tu1 -N24 "$out")
  if [ $# -ge 24 ] && [ "$1 $2 $3 $4" = "137 80 78 71" ]; then
    w=$(( (${17} << 24) | (${18} << 16) | (${19} << 8) | ${20} ))
    h=$(( (${21} << 24) | (${22} << 16) | (${23} << 8) | ${24} ))
    dims="${w}x${h} PNG, "
  fi
  echo "codex-gen: wrote $out (${dims}$(human_size "$(wc -c < "$out" | tr -d ' ')")) in ${elapsed}s"
  [ "$count" -le 1 ] || echo "codex-gen: note: Codex generated $count images; kept the newest. The others are in $gen_dir"
  echo "codex-gen: Codex says: $(tr -d '\r' < "$tmp/last.md" | head -n 3)"
  exit 0
fi

# --- text mode: clean up and save -----------------------------------------------
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
