---
name: asset
description: Delegate writing a markdown asset to OpenAI Codex (the Codex CLI) and save it in the project, one .md file per call. Use when the user asks for Codex to generate, write, draft or revise something (game design docs, lore, dialogue, quest/level/item/enemy specs, story bibles, copy, docs, prompts), when they have said that assets should be delegated to Codex, or when they run /codex-harness:asset.
---

# Generate an asset with Codex

You (Claude) stay in charge. You decide which assets are needed, brief Codex, then read and use what it writes. Each call to `scripts/codex-gen.sh` (in this skill's base directory) has Codex write **exactly one markdown file**. Codex runs read-only: it can read the project for context, and the script, not Codex, writes the file.

## 1. Write the brief

Codex has not seen this conversation, so the brief must stand on its own. Cover:

- what the asset is and what it will be used for (for example "parsed by `src/data/loadEnemies.ts`" or "read by the designer")
- tone, audience and setting
- the structure you need: headings, tables, a fixed schema per entry, field names and units
- how much: "12 enemies", "3 acts", "~800 words"
- constraints from the codebase: existing names and IDs, stat ranges, things it must not contradict
- what to leave out

If code will parse the file, specify the format exactly, ideally with one example entry.

Choose the output path. Follow the project's conventions if it has them, otherwise use `assets/<kebab-case-name>.md`.

## 2. Run it

From the project root (paths are relative to it; use forward slashes in the script path, also on Windows):

```bash
bash "<skill base dir>/scripts/codex-gen.sh" assets/bestiary.md --ref docs/game-design.md --ref src/data/enemy.ts <<'BRIEF'
Write the bestiary for ...
BRIEF
```

- `--ref <file>` (repeatable): files Codex should read first, such as the design doc, related assets, or the source that defines the data shape. This costs less than pasting their contents into the brief.
- `--overwrite`: replace an existing file. To revise an asset, pass the file as `--ref` **and** `--overwrite`, and describe the changes in the brief.
- `--model <name>` / `--effort <low|medium|high>`: optional. Otherwise the user's Codex config applies.
- One call takes about 30 seconds to 5 minutes. Run it with a Bash `timeout` of `600000`. For several assets, start each call with `run_in_background: true` so they run in parallel, and carry on until they finish.
- If the project root has a `CODEX_STYLE.md`, the script adds it to every brief automatically. Suggest creating one when the user wants a consistent voice or format across many assets.

On success the script prints `codex-gen: wrote <path> (N lines, B bytes) in Ns`.

## 3. Use the result

Read the file and check it against the brief. Then put it to work: implement from it, parse it, link it. Small fixes you can make yourself. If it misses the brief badly, re-run with a sharper brief and `--overwrite` rather than rewriting it by hand. Tell the user which files Codex wrote.

## If it fails

- `codex CLI not found`: the user must install and log in: `npm i -g @openai/codex`, then `codex login`. Suggest they type `! codex login` here.
- Authentication or usage-limit errors in the output: report them to the user. Do not retry in a loop.
- `already exists`: pick another name, or use `--ref` + `--overwrite` if a revision was intended. If the file looks hand-written by the user, ask before overwriting.
- Never quietly write the asset yourself instead. Say Codex failed and ask whether to retry or have you write it.

## Invoked as a command

If arguments came with the invocation (for example `/codex-harness:asset 10 enemy types for a desert level`), they are the request. Turn them into a full brief as above, choose a path, and run it.
