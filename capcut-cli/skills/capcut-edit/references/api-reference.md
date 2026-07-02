# capcut-cli API reference

Every command, every flag, every value format. Companion to `SKILL.md` — skip
this doc for orientation, come here when writing a script or needing a flag
default.

---

## Global

### Invocation

```
capcut <command> <project> [args] [flags]
```

`<project>` is one of:

- a supported timeline file (`draft_content.json`, `draft_info.json`, `draft_meta_info.json`, `template-2.tmp`)
- a directory containing one or more supported timeline targets

### Global flags

| Flag | Alias | Effect |
|---|---|---|
| `--human` | `-H` | Human-readable table output. Default is JSON. |
| `--quiet` | `-q` | No stdout on success; exit code only. Use in scripts for write commands. |
| `--jianying` | — | Switch enum namespace to JianYing (default: CapCut). Applies to `transition`, `mask`, `text-anim`, `image-anim`, `add-effect`, `enums`. |
| `--dry-run` | — | Preview a mutation without writing or creating backups. |
| `--force-write` | — | Override changed-on-disk/editor-running safety. Use only with explicit user acceptance. |

### `.bak` invariant

Every write conflict-checks the loaded files, prepares same-directory temporary
files, fsyncs, and renames atomically. Every readable timeline target is
synchronized and receives a `.bak` plus rolling `.capcut-cli-history/`
snapshots. Use `capcut restore <project> [--step N | --list]`.

### ID prefix rule

Every command that takes `<id>` accepts the first 6+ characters of the segment
or material UUID as a prefix match. First match wins. Case-sensitive.

### Time format

Every `<time>` / `<start>` / `<duration>` / `<offset>` argument:

| Form | Meaning |
|---|---|
| `1.5s` | 1.5 seconds |
| `500ms` | 500 milliseconds |
| `+0.5s` / `-1s` | signed offset (shifts) |
| `1:30` | 1 minute 30 seconds |
| `1:02:03.5` | 1 hour 2 minutes 3.5 seconds |
| `0:05.5` | 5.5 seconds |
| `1.5` (bare) | 1.5 seconds |

Internally stored as microseconds (integer). Round-trip safe.

---

## Overview

### `capcut info <project>`

Prints project metadata: id, duration, fps, canvas size, track counts, material
type counts. With `-H`: table. With default JSON: object.

### `capcut tracks <project>`

Lists every track with: index, type (`video` / `audio` / `text` / `sticker` /
`effect`), name, segment count, total duration.

### `capcut materials <project> [--type <type>]`

No flag: counts per material type. With `--type <type>`: one row per material of
that type. `<type>` ∈ `videos`, `audios`, `texts`, `material_animations`,
`transitions`, `effects`, `speeds`, etc. (whatever keys exist under
`materials.*`).

---

## Browse

### `capcut segments <project> [--track <type>]`

All segments across all tracks, each row: id-prefix, track type, start-end
timecodes, duration, speed, label (derived from material name). With `--track
<type>`: filter to that track type only.

### `capcut texts <project>`

All text segments, shortest form: id, start-end, text body. Covers intros,
subtitles, lower-thirds — everything on a `text` track.

---

## Detail

### `capcut segment <project> <id>`

Full segment record + joined material record. Use for deep inspection.

### `capcut material <project> <id>`

Full material record. Not limited to one type — searches every `materials.*`
array.

---

## Create

### `capcut init <name> [--template <dir>] [--drafts <dir>]`

Copies a template draft directory into the drafts folder under the given name.

| Flag | Default | Effect |
|---|---|---|
| `--template <dir>` | `../CapCutAPI/template` (relative to capcut-cli) | Template source directory. |
| `--drafts <dir>` | `~/Movies/CapCut/User Data/Projects/com.lveditor.draft` | Drafts parent directory. |

---

## Add

### `capcut add-audio <project> <file> <start> <duration> [flags]`

Adds an audio segment. `<file>` is resolved relative to the project's
`assets/audio/` folder if not absolute.

| Flag | Default | Effect |
|---|---|---|
| `--volume <n>` | `1.0` | 0.0–1.0 |
| `--track-name <s>` | `"audio"` | Target audio track name; creates on demand. |

### `capcut add-video <project> <file> <start> <duration> [flags]`

Adds a video or image segment. Type auto-detected from file extension
(`.mp4`/`.mov`/… = video, `.jpg`/`.png`/… = image). Source-timerange auto-fit to
the requested target duration for images.

| Flag | Default | Effect |
|---|---|---|
| `--track-name <s>` | `"video"` | Target video track name; creates on demand. |

### `capcut add-text <project> <start> <duration> <text> [flags]`

Adds a text segment with default styling.

| Flag | Default | Effect |
|---|---|---|
| `--font-size <n>` | `15` | Font size. |
| `--color <hex>` | `#FFFFFF` | Text color, `#RRGGBB`. |
| `--align <0\|1\|2>` | `1` | 0=left, 1=center, 2=right. |
| `--x <n>` | `0` | Horizontal position, `-1`–`1` (half-canvas units). |
| `--y <n>` | `0` | Vertical position, `-1`–`1`. |
| `--track-name <s>` | `"text"` | Target text track name; creates on demand. |

---

## Edit

### `capcut set-text <project> <id> <text>`

Replaces the text content of a text segment. No other styling changes.

### `capcut shift <project> <id> <offset>`

Shifts one segment's `target_timerange.start` by the offset (accepts signed
times).

### `capcut shift-all <project> <offset> [--track <type>]`

Shifts every segment by the offset. `--track <type>` narrows to one track type.

### `capcut speed <project> <id> <multiplier>`

Sets segment playback speed. `<multiplier>` is a bare number (`1.5`, `0.5`).
Adjusts `source_timerange.duration` to preserve the target duration.

### `capcut volume <project> <id> <level>`

Sets segment volume. `<level>` ∈ `0.0`–`1.0`.

### `capcut trim <project> <id> <start> <duration>`

Re-trims the segment's `source_timerange` to `[start, start+duration]` within
the source media.

### `capcut opacity <project> <id> <alpha>`

Sets the segment `clip.alpha` base value. `<alpha>` ∈ `0.0`–`1.0`.

### `capcut export-srt <project>`

Prints all text segments as SRT on stdout.

### `capcut batch <project>`

Reads JSONL on stdin; each line is `{"cmd": "<op>", "id": "<prefix>", ...opArgs}`.

Operations: `set-text`, `shift`, `shift-all`, `speed`, `volume`, `opacity`,
`trim`. Args mirror the standalone commands.

---

## Animate

### `capcut keyframe <project> <id> <property> <time> <value>`

Single keyframe; or batch with `--batch` reading JSONL on stdin:
`{"property":"alpha","time":"0.5s","value":"1.0"}`.

**⚠ Fades:** `alpha` keyframes are ignored by CapCut macOS (verified on 8.5.0
beta — neither video nor text segments respect them as a visible fade). For
fade-in / fade-out, use `scripts/fade-in.sh` (a Fade In animation material) —
not this command. `keyframe` is still correct for position, scale, rotation,
color properties.

| Property | Value format | Range |
|---|---|---|
| `position_x` / `position_y` | bare number | `-10`–`10` (half-canvas units) |
| `rotation` | `45deg` or bare | any degrees |
| `scale_x` / `scale_y` / `uniform_scale` | bare number | `0.0`+ |
| `alpha` | `1.0` or `50%` | `0.0`–`1.0` (non-rendering for fades — see above) |
| `volume` | `1.0` or `80%` | `0.0`–`1.0`+ |
| `saturation` / `contrast` / `brightness` | `+0.5` / `-0.3` / bare | `-1.0`–`1.0` |

### `capcut transition <project> <id> <slug> [--duration <s>]`

Attaches a transition to a video/image segment. Transitions live at
`materials.transitions` and are referenced via the segment's
`extra_material_refs`. Only one transition per segment — call fails otherwise.

Slug catalogue is sourced from `enums.json` (116 CapCut transitions, 362
JianYing). Run `capcut enums --transitions -H` for the full list. Commonly-used
slugs include:

| Slug | Default duration | is_overlap |
|---|---|---|
| `dissolve` | 466ms | false |
| `rgb-glitch` | 1.0s | true |
| `radial-blur` | 466ms | false |
| `horizontal-blur` | 466ms | true |
| `vertical-blur-ii` | 600ms | true |
| `twinkle-zoom` | 1.0s | true |
| `urban-glitch` | 1.0s | true |
| `shake-3` | 800ms | true |

### `capcut mask <project> <id> <slug> [flags]`  ·  `... --off`

Attaches a mask to a video/image segment, or removes all masks with `--off`.
Masks live at `materials.common_mask` (CapCut) and reference via the
segment's `extra_material_refs`. Only one mask per segment.

Slugs from `enums.json`; list via `capcut enums --masks -H`. Legacy aliases
preserved:

| Slug | Alias of | Shape |
|---|---|---|
| `linear` | `split` | straight split |
| `mirror` | `filmstrip` | filmstrip |
| `circle` | — | circle |
| `rectangle` | — | rectangle (supports `--rect-width`, `--round-corner`) |
| `heart` | — | heart |
| `star` | `stars` | pentagram |
| `text` / `brush` / `pen` | — | also in catalogue (require extra config) |

| Flag | Default | Range | Effect |
|---|---|---|---|
| `--center-x` | `0` | `-1`–`1` | Horizontal centre (half-canvas units). |
| `--center-y` | `0` | `-1`–`1` | Vertical centre. |
| `--size` | `0.5` | `0`–`1` | Main dimension as fraction of canvas height. |
| `--rotation` | `0` | degrees | Clockwise rotation. |
| `--feather` | `0` | `0`–`100` | Feather amount (stored as 0–1 internally). |
| `--invert` | off | flag | Invert the mask. |
| `--rect-width` | = `--size` | `0`–`1` | Rectangle-only. Width as fraction of canvas width. |
| `--round-corner` | `0` | `0`–`100` | Rectangle-only. |

### `capcut bg-blur <project> <id> <1|2|3|4>`  ·  `... --off`

Sets background-filling blur on the underlying track. Four levels (matching
CapCut's UI quickpicks): 1=0.0625, 2=0.375, 3=0.75, 4=1.0. `--off` removes
every canvas material from the segment's refs. Background filling only
renders on **bottom-track** video segments.

### `capcut text-ranges <project> <id> --styles @path.json`

Phase 4. Writes multiple `TextStyleRange` entries to a text material's
`content.styles` array so different character ranges render in different
colors / sizes / weights. Unlocks word-level highlight captions.

Input is a JSON array — either `@path.json` or inline — of range objects:

```json
[
  {"start": 0, "end": 5,  "font_color": "#FFD700", "font_size": 22, "bold": true},
  {"start": 6, "end": 14, "font_color": "#FF0000"}
]
```

| Field | Type | Effect |
|---|---|---|
| `start` / `end` | integer | JS string code-unit indices (char-level for BMP; `end` exclusive). |
| `font_color` | `"#RRGGBB"` | Fill color. Inherits the material's baseline color when omitted. |
| `font_size` | number | Size in pt. Inherits baseline. |
| `font_alpha` | 0–1 | Fill alpha. Inherits baseline. |
| `bold` / `italic` / `underline` | boolean | Typeface flags. Inherit baseline. |

**Gap handling:** the writer sorts ranges, validates non-overlap (error
otherwise), then emits one style per range + baseline-style fillers between
ranges so CapCut renders the whole text without blank spans.

**Byte offsets:** internally `range` is stored as UTF-16LE bytes
(`Buffer.from(text.slice(0, codeUnit), 'utf16le').length`). Input uses
code-unit indices so callers don't have to care about encoding.

Output: `{ ok, segmentId, material_id, styles, text_length }`.

Example (highlight first word of a caption):

```bash
capcut text-ranges ./project a1b2c3 --styles '[
  {"start":0,"end":5,"font_color":"#FFD700","bold":true},
  {"start":6,"end":14,"font_color":"#FFFFFF"}
]'
```

### `capcut text-style <project> <id> [flags]`

Updates an existing text segment's material-level styling (shadow, border,
background box, vertical orientation, alpha, fixed dimensions). All flags
optional; at least one required.

| Flag | Type | Effect |
|---|---|---|
| `--alpha <n>` | `0`–`1` | Text opacity. |
| `--vertical` | flag | Vertical typesetting. |
| `--fixed-width <n>` | float | Pins bbox width. |
| `--fixed-height <n>` | float | Pins bbox height. |
| `--shadow` / `--no-shadow` | flag | Turn shadow on/off. |
| `--shadow-alpha <n>` | `0`–`1` |  |
| `--shadow-angle <deg>` | float |  |
| `--shadow-color <hex>` | `#RRGGBB` |  |
| `--shadow-distance <n>` | float |  |
| `--shadow-smoothing <n>` | `0`–`1` |  |
| `--border-width <n>` | float | Any border-* flag enables the border. |
| `--border-color <hex>` | `#RRGGBB` |  |
| `--border-alpha <n>` | `0`–`1` |  |
| `--bg-color <hex>` | `#RRGGBB` | Any bg-* flag enables the background box. |
| `--bg-alpha <n>` | `0`–`1` |  |
| `--bg-style <n>` | int |  |
| `--bg-round-radius <n>` | float |  |
| `--bg-width <n>` | float |  |
| `--bg-height <n>` | float |  |
| `--bg-h-offset <n>` | float |  |
| `--bg-v-offset <n>` | float |  |

### `capcut text-anim <project> <id> [--intro <slug>] [--outro <slug>]`

Attaches intro/outro animations to a text segment. Creates or extends the
`sticker_animation` container and references via `extra_material_refs`.

Slugs come from `enums.json` (`text_intros` / `text_outros` categories) — 76
CapCut intros + 68 outros. Browse with `capcut enums --text-intros -H` or
`--text-outros -H`. Featured slugs used in existing skills/scripts:

| Slug | Type | Enum alias | Default dur |
|---|---|---|---|
| `fade-in` | in | `fade-in` | 500ms |
| `typewriter` | in | `typewriter` | 500ms |
| `pop-up` | in | `pop-up` | 500ms |
| `throw-out` | in | `throw-out` | 500ms |
| `blur-text-in` | in | `blur` | 500ms |
| `zoom-in-text` | in | `zoom-in` | 500ms |
| `fade-out` | out | `fade-out` | 500ms |

Optional `--intro-duration <s>` / `--outro-duration <s>` override the slug's
default. Segment max caps are enforced.

### `capcut image-anim <project> <id> [--intro <slug>] [--outro <slug>] [--combo <slug>]`

Attaches video/image intro/outro/combo animations to a video or image
segment. Same mechanism as `text-anim` but `material_type: "video"` and a
different slug catalogue matching `skills/capcut-edit/assets/animations.json`.

Intros: `fade-in`, `flash-in`, `pulsing-zooms`, `scroll-up`, `stripe-merge`,
`zoom-out`. Outros: `fade-out`, `blur-out`, `smoke`. These nine slugs keep
their empirically-verified knossos-recon `effect_id`s; any other slug falls
through to `enums.json` (`image_intros` / `image_outros` / `image_combos`).
List the full catalogue via `capcut enums --image-intros`, `--image-outros`,
or `--image-combos` (108 CapCut combos, 43 intros, 23 outros).

Optional `--intro-duration <s>` / `--outro-duration <s>` / `--combo-duration <s>`.
For images used on the main video track, `scripts/fade-in.sh` / `fade-out.sh`
remain the preferred ergonomic entry points for their specific slugs.

---

## Tracks (Phase 2)

### `capcut add-sticker <project> <resource-id> <start> <duration> [flags]`

Creates a sticker segment on a sticker track. Creates the track on demand.
Sticker materials are stored at `materials.stickers`.

| Flag | Default | Effect |
|---|---|---|
| `--x <n>` | `0` | Horizontal position, `-1`–`1` half-canvas units. |
| `--y <n>` | `0` | Vertical position. |
| `--scale <n>` | `1` | Uniform scale. |
| `--rotation <deg>` | `0` | Clockwise rotation. |
| `--track-name <s>` | `"sticker"` | Target sticker track; creates on demand. |

**Resource-id:** each CapCut sticker has a unique `resource_id` — look it up
in an existing project via `capcut material <project> <sticker-material-id>`.
(`capcut enums --stickers` is not wired: the upstream pyJianYingDraft does not
publish a sticker enum.)

### `capcut add-effect <project> <slug> <start> <duration> [flags]`

Creates a scene or character effect segment on an effect track. Effect
applies to the whole track (apply_target_type=2) for the timerange. Effect
materials stored at `materials.video_effects`.

Slugs: inline starter catalogue (below) with knossos-verified `effect_id`s wins
first; any other slug falls through to `enums.json` (`scene_effects` → `video_effect`,
`character_effects` → `face_effect`). Full list via
`capcut enums --scene-effects -H` (345 CapCut, 912 JianYing) or
`--character-effects`.

| Slug | Name | effect_type |
|---|---|---|
| `shake` | Shake | video_effect |
| `vhs` | VHS | video_effect |
| `cinematic` | Cinematic | video_effect |
| `light-leak` | Light Leak | video_effect |
| `film-grain` | Film Grain | video_effect |
| `chromatic` | Chromatic | video_effect |
| `vignette` | Vignette | video_effect |

| Flag | Default | Effect |
|---|---|---|
| `--params <json>` | `[]` | JSON array of numbers, each 0-100. Meaning is per-effect. |
| `--track-name <s>` | `"effect"` | Target effect track; creates on demand. |

---

## Templates

### `capcut save-template <project> <id> <name> --out <path>`

Extracts a segment + its material (and any extra materials referenced via
`extra_material_refs`) to a standalone template JSON at `--out`.

### `capcut apply-template <project> <template.json> <start> <duration> [text-override]`

Stamps a saved template into the project at `<start>` for `<duration>`.
Optional `text-override` replaces the text body on any text segments inside.

| Flag | Default | Effect |
|---|---|---|
| `--x <n>` | template's | Override horizontal position. |
| `--y <n>` | template's | Override vertical position. |

---

## Project

### `capcut cut <project> <start> <end> --out <path>`

Extracts the range `[start, end]` into a new draft file at `--out`. Source
project is not modified. Edge segments are clipped; empty tracks are removed;
orphaned materials are pruned. Timing rebased to 0 in the output.

---

## Discovery (Phase 3)

### `capcut enums <flag> [--jianying] [-H]`

Lists valid enum slugs + metadata for a given CapCut (or JianYing) category.
Reads from the committed `dist/enums.json` bundle generated by
`scripts/extract-enums.py`. No project argument.

| Flag | Category |
|---|---|
| `--transitions` | Cross-clip transitions. Metadata: `name`, `slug`, `member`, `effect_id`, `resource_id`, `md5`, `default_duration` (us), `is_overlap`, `is_vip`. |
| `--masks` | Video/image masks. Metadata adds `resource_type`, `default_aspect_ratio`. |
| `--image-intros` / `--image-outros` / `--image-combos` | Video/image segment animations (`Animation_meta`: `title`, `duration` us, `effect_id`, `resource_id`, `md5`, `is_vip`). |
| `--text-intros` / `--text-outros` / `--text-loop-anims` | Text segment animations (same shape as image anims). |
| `--scene-effects` / `--character-effects` | Video effect track entries (`Effect_meta`: `name`, `effect_id`, `resource_id`, `md5`). Scene effects = `video_effect`; character = `face_effect`. |
| `--audio-effects` | Audio scene effects / CapCut voice filters. |
| `--fonts` | JianYing only (no CapCut variant upstream). |

`--jianying` switches to the JianYing namespace for the chosen category; some
members carry non-ASCII (Chinese) Python identifiers and will have `slug: ""` —
reference those by `member` instead.

Output: JSON array (default) or `-H` table (`slug`, `name`/`title`, `member`).

Example:

```bash
capcut enums --transitions -H | head
capcut enums --scene-effects | jq '.[] | select(.slug | startswith("cine"))'
```

### Rebuilding `enums.json`

```bash
cd capcut-cli
python3 scripts/extract-enums.py    # imports ../CapCutAPI/pyJianYingDraft
npm run build                        # tsc && copy enums.json into dist/
```

The extractor is a one-shot build step. Runtime is Python-free.

---

## Network inputs — Wikimedia Commons

`add-video` and `add-audio` accept a Wikimedia URL anywhere they accept a file
path. Accepted hosts:

- `commons.wikimedia.org/wiki/File:...`
- `en.wikipedia.org/wiki/File:...` (any `*.wikipedia.org` language edition)
- `upload.wikimedia.org/wikipedia/commons/...` (direct CDN)
- `en.wikipedia.org/w/api.php?...&prop=pageimages&piprop=original&...`
   (pageimages — the API call resolves to the page's representative image)

Non-Wikimedia URLs are refused before any network call. For other sources,
download separately and pass a local path.

### Flow

1. Parse the URL → extract a `File:Foo.jpg` title (or resolve the pageimages
   API response to one).
2. Call `commons.wikimedia.org/w/api.php?action=query&prop=imageinfo&iiprop=url|size|mime|extmetadata&titles=...`
   with `User-Agent: capcut-cli/...` (Wikimedia 403s anonymous clients).
3. Classify `extmetadata.LicenseShortName`:
   - **permissive**: CC0 / CC BY / CC BY-SA / Public domain / PD / No restrictions → download.
   - **fair-use**: `fair use` / `fair dealing` → download, but print a warning.
   - **restrictive**: CC BY-NC / CC BY-ND / non-commercial / © / copyrighted → refuse unless `--force-license`.
   - **unknown**: missing LicenseShortName → refuse unless `--force-license`.
4. Stream the file to `<draft>/assets/video|audio/<filename>` (matches the
   existing asset dir so the internal copy step is a no-op).

### Output

On success, the JSON gets a `wikimedia` block:

```json
{
  "ok": true,
  "segment_id": "...",
  "path": "...",
  "wikimedia": {
    "file_title": "File:Foo.jpg",
    "license": "CC BY 2.0",
    "license_class": "permissive",
    "artist": "Jane Doe",
    "credit": "https://example.com/source",
    "description_url": "https://commons.wikimedia.org/wiki/File:Foo.jpg",
    "width": 4000, "height": 3000, "mime": "image/jpeg"
  }
}
```

Attribution the CC-BY family requires: use `artist` + `description_url` in
your YouTube description. `--force-license` puts the responsibility on you.

### Examples

```bash
# User's Barcelona pageimages example
capcut add-video ./project \
  "https://en.wikipedia.org/w/api.php?action=query&titles=Barcelona&prop=pageimages&piprop=original&format=json" \
  0s 5s

# Direct Commons File: page
capcut add-video ./project \
  "https://commons.wikimedia.org/wiki/File:Knossos_north_portico.jpg" \
  5s 5s

# Direct CDN (still license-checks)
capcut add-video ./project \
  "https://upload.wikimedia.org/wikipedia/commons/1/1b/Aerial_view_of_Barcelona.jpg" \
  10s 5s

# Bypass refusal (you assume responsibility)
capcut add-video ./project \
  "https://en.wikipedia.org/wiki/File:Dark_Side_of_the_Moon.jpg" \
  15s 5s --force-license
```

---

## Subtitles (Phase 3)

### `capcut import-srt <project> <srt-path-or--> [flags]`

Parses an SRT file (or `-` for stdin) and creates one text segment per cue on
the target text track. All cues are added under a single `saveDraft` call, so
even large subtitle files stay fast.

Zero-dep SRT parser in `src/srt.ts` — accepts `.` or `,` as the millisecond
separator; optional index lines; blank lines between cues.

| Flag | Default | Effect |
|---|---|---|
| `--track-name <s>` | `subtitle` | Text track to add cues to (created if missing). |
| `--time-offset <s>` | `0` | Shift every cue start by this signed duration. Negative shifts that push cue 1 below 0us error out. |
| `--style-ref <seg-id>` | – | Copy styling (`font_size`, colors, shadow/border/background, fill in `content.styles[0]`) from an existing text segment onto every new cue. Fails fast if the ref isn't found. |
| `--font-size <n>` / `--color <hex>` / `--align <0\|1\|2>` / `--x <n>` / `--y <n>` | matches `add-text` | Explicit styling when no `--style-ref`. |
| text-style flags | – | `--alpha`, `--vertical`, `--shadow` (+ `--shadow-*`), `--border-*`, `--bg-*` — same semantics as `capcut text-style`. Applied to every new cue after `--style-ref` (so explicit flags win). |

Output: `{ ok, cues, track_name, style_ref, time_offset_us, first, last }` where
`first`/`last` are `{id, start_us, duration_us, text}`.

Example (pipe Whisper output in):

```bash
faster-whisper ... --output-format srt \
  | capcut import-srt ~/Movies/.../knossos-recon - \
      --track-name captions \
      --style-ref cccccc01 \
      --time-offset -120ms
```

---

## v0.11 reliability and automation

The generated [`docs/command-reference.md`](../../../docs/command-reference.md)
is the exhaustive flag/type/default source. Important v0.11 paths:

### `capcut diagnose <project> [--bundle <report.json>]`

Reports canonical-file selection, hashes, readable timeline envelopes,
divergence, app version, and running CapCut/JianYing processes without exposing
media paths. Use `--bundle` for issue attachments.

### `capcut compile <spec.json> [--check | --plan | --out <dir>]`

Specs support stable item `ref` values and top-level `operations`: transition,
filter, effect, keyframe, audio-fade, text-style, text-ranges, template, and
captions. Media items accept source timing, speed, opacity, rotation, scale,
position, volume, and auto-probed duration. `--check`/`--plan` never write.

### `capcut caption <project> ... --karaoke`

Select a dialect with `--whisper-engine openai|whisper-cpp|faster-whisper`.
Word-timestamp JSON is grouped with `--max-words`, `--max-chars`, and
`--max-gap-ms`; each word interval becomes a real highlighted caption segment.

### `capcut render <project> --all-video-tracks --burn-captions`

Composites overlay tracks with transform/opacity, mixes audio fades, and uses
draft caption colour/size/position. `doctor` reports `drawtext`, `overlay`, and
`libx264`; missing optional filters produce an explicit fallback report.

### `capcut serve [--workers N] [--retries N] [--timeout MS]`

JSONL jobs may carry stable `id`, per-job `timeoutMs`/`retries`, `project`, and
`args`. Different projects may run concurrently; writes to one project are
serialized. `--backoff-ms` and `--max-buffer-mb` bound retry/output behavior.

---

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success. |
| `1` | Command-level failure (segment not found, invalid value, …). Prints JSON `{"error":"..."}` on stdout. |
| `2` | Usage error (missing args, unknown flag). Prints a usage line on stderr. |
