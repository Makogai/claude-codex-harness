---
name: asset
description: Delegate making an asset to OpenAI Codex (the Codex CLI) and save it in the project, one file per call. Either a markdown document (game design docs, lore, dialogue, quest/level/item/enemy specs, story bibles, copy, docs, prompts) or a PNG image from Codex's image generation (icons, sprites, concept art, illustrations, textures). Use when the user asks for Codex to generate, write, draw, draft or revise something, when they have said that assets should be delegated to Codex, or when they run /codex-harness:asset.
---

# Make an asset with Codex

You (Claude) stay in charge. You decide which assets are needed, brief Codex, then check and use what it makes. Each call to `scripts/codex-gen.sh` (in this skill's base directory) makes **exactly one file** in the project. The output path's extension picks the mode:

| Output | Codex does | The script then |
|---|---|---|
| `something.md` | writes a markdown document, read-only | saves Codex's answer to that path |
| `something.png` | makes an image with its built-in image generation | moves the image from `~/.codex/generated_images` to that path |

Codex never writes into the project itself. The script puts the result there.

## 1. Write the brief

Codex has not seen this conversation, so the brief must stand on its own.

**For documents**, cover:
- what the asset is and what it will be used for (for example "parsed by `src/data/loadEnemies.ts`" or "read by the designer")
- tone, audience and setting
- the structure you need: headings, tables, a fixed schema per entry, field names and units
- how much: "12 enemies", "3 acts", "~800 words"
- constraints from the codebase: existing names and IDs, stat ranges, things it must not contradict
- what to leave out

If code will parse the file, specify the format exactly, ideally with one example entry.

**For images**, cover:
- the subject and what the image is for (app icon, game sprite, background, concept art)
- style: flat, painterly, pixel art, 3D, photographic; plus mood and lighting
- composition and framing: aspect ratio, centered or edge-to-edge, empty margins, plain or transparent-looking background
- palette, if it matters
- what to avoid: text and lettering (image models garble it), watermarks, specific logos
- for icons: "must stay readable at 32x32 px", one bold symbol, no fine detail

Choose the output path. Follow the project's conventions if it has them, otherwise use `assets/<kebab-case-name>.md` or `.png`.

## 2. Run it

From the project root (paths are relative to it; use forward slashes in the script path, also on Windows):

```bash
bash "<skill base dir>/scripts/codex-gen.sh" assets/bestiary.md --ref docs/game-design.md --ref src/data/enemy.ts <<'BRIEF'
Write the bestiary for ...
BRIEF

bash "<skill base dir>/scripts/codex-gen.sh" assets/sprites/lantern.png --ref docs/art-style.md <<'BRIEF'
A single game sprite: ...
BRIEF
```

- `--ref <file>` (repeatable): context for Codex.
  - **Text files** (design doc, related assets, source that defines a data shape) are pasted into the prompt.
  - **Images** (`.png .jpg .jpeg .webp .gif`) are attached so Codex can see them. Use them for "a variant of this", "match this style", or "describe/review this image".
- `--overwrite`: replace an existing file. To revise an asset, pass the file as `--ref` **and** `--overwrite`, and describe the changes in the brief. This works for images too.
- `--model <name>` / `--effort <low|medium|high>`: optional. Otherwise the user's Codex config applies.
- Documents take about 10 seconds to 5 minutes, images about a minute. Run with a Bash `timeout` of `600000`. For several assets, start each call with `run_in_background: true` so they run in parallel, and carry on until they finish.
- If the project root has a `CODEX_STYLE.md`, the script adds it to every brief automatically. Suggest creating one when the user wants a consistent voice, art style or format across many assets.

On success the script prints `codex-gen: wrote <path> (...) in Ns`. For images it gives the pixel size and Codex's one-line description.

## 3. Use the result

**Documents:** read the file and check it against the brief, then put it to work: implement from it, parse it, link it. Small fixes you can make yourself. If it misses the brief badly, re-run with a sharper brief and `--overwrite` rather than rewriting it by hand.

**Images:** look at the image (read the file) and check it against the brief. Image generation picks its own resolution (often about 1254 px square). If the user needs an exact size or format (1024x1024, a sprite sheet, .ico), convert it afterwards with whatever is available: Python Pillow, ImageMagick, or `sips` on macOS. For icons, check that it still reads when scaled down to 32 px. If it misses, re-run with a sharper brief, passing the image as `--ref` with `--overwrite`.

Tell the user which files Codex made.

## If it fails

- `codex CLI not found`: the user must install and log in: `npm i -g @openai/codex`, then `codex login`. Suggest they type `! codex login` here, or run `/codex-harness:setup`.
- `image generation is not available`: image generation needs a ChatGPT login rather than only an API key, plus a current Codex (`codex update`). Report this to the user.
- Authentication or usage-limit errors in the output: report them to the user. Do not retry in a loop.
- `already exists`: pick another name, or use `--ref` + `--overwrite` if a revision was intended. If the file looks hand-made by the user, ask before overwriting.
- Never quietly make the asset yourself instead (no drawing an "image" with SVG or code). Say Codex failed and ask whether to retry or try another approach.

## Invoked as a command

If arguments came with the invocation (for example `/codex-harness:asset 10 enemy types for a desert level` or `/codex-harness:asset a pixel-art lantern sprite`), they are the request. Decide whether it's a document or an image, turn it into a full brief as above, choose a path, and run it.
