---
name: Auto-subtitle — burned-in karaoke captions via fal-ai/workflow-utilities/auto-subtitle
description: For burned-in captions on UGC ad content, ALWAYS use `quickdesign video subtitle` AFTER generation. The endpoint runs ElevenLabs ASR on the actual audio (word-level timing) and renders styled captions with libass — accurate, customizable, no hallucination. Never let Seedance burn its own subtitles via prompt — those are pixel-burned hallucinations that don't match the audio.
---

## When to use

Add subtitles in post-production whenever the user wants:
- Burned-in captions on a UGC reel / TikTok / Reels content
- Karaoke-style word-by-word highlights
- Multi-language transcription with custom font / color styling
- Text overlay that perfectly matches the spoken audio

**NEVER** let Seedance burn captions via the prompt. Seedance's prompt-derived subtitles hallucinate (partial sentences, paraphrased words, wrong timing). The dedicated subtitle endpoint uses real ASR on the generated audio — bulletproof accuracy.

## CLI usage

```bash
# Default: TikTok-style, English, single-word karaoke highlight
quickdesign video subtitle ./final.mp4 -o ./final-subbed.mp4 --wait

# Different style + language
quickdesign video subtitle ./final.mp4 \
  --style minimal \
  --language tr \
  -o ./final-tr-subbed.mp4 --wait

# Style override (preset + custom flags)
quickdesign video subtitle ./final.mp4 \
  --style tiktok \
  --font Poppins \
  --highlight-color cyan \
  --words-per-line 2 \
  -o ./final-custom.mp4 --wait
```

## Style presets

The `--style <preset>` flag selects a baseline; any explicit `--<flag>` overrides individual fields.

| Preset | Font | Size | Weight | Color | Highlight | Stroke | Pos | Words/line | Anim | Use case |
|---|---|---|---|---|---|---|---|---|---|---|
| `default` (default) | Montserrat | **65** | bold | white | yellow | 2 black | bottom +60 | **5** | on | Balanced, readable, works for most content |
| `tiktok` | Montserrat | 100 | bold | white | purple | 3 black | bottom +75 | **1** | on | UGC creator content, vertical reels, single-word pop |
| `minimal` | Inter | 60 | normal | white | white (none) | 1 black | bottom +50 | **8** | off | Editorial, brand ad, professional |
| `karaoke` | Montserrat | 80 | bold | white | yellow | 2 black | center 0 | **3** | on | Music / lyric content |
| `reels-pop` | Bebas Neue | 110 | black | yellow | red | 4 black | center -50 | **1** | on | Punchy hook content, attention-grab |

## Override flags (apply on top of preset)

```
--language <code>          en | tr | es | fr | de | ... (or 3-letter ISO)
--font <name>              Any Google Font name (Montserrat, Inter, Poppins, Bebas Neue, etc.)
--font-size <n>            px
--font-weight <w>          normal | bold | black
--color <c>                white | black | red | green | blue | yellow | orange | purple | pink | brown | gray | cyan | magenta
--highlight-color <c>      same color enum
--stroke-width <n>         px (0 = no outline)
--stroke-color <c>         outline color
--background-color <c>     same enum + 'none' / 'transparent'
--background-opacity <n>   0.0–1.0
--position <p>             top | center | bottom
--y-offset <n>             vertical px (positive = down)
--words-per-line <n>       1 = single-word (TikTok), 3 = phrase, 8-12 = full sentence
--no-animation             Disable bounce-in animation
```

## Cost

$0.03 per minute of source video on fal.ai → **1 credit per second** at our standard rate (60cr/min, ~50% margin). Minimum 20cr per call to cover infra overhead.

| Source duration | Cost (cr) |
|---|---|
| 8s | 20 (min) |
| 15s | 20 (min) |
| 30s | 30 |
| 44s | 44 |
| 60s | 60 |
| 90s | 90 |

## How to apply

1. **Default flow**: generate the video clean (no Seedance subtitles per `no-music-no-subtitles.md` rule), then run `quickdesign video subtitle` on the final concat'd output.

2. **Multi-segment UGC pipelines**: subtitle the FINAL concat'd video, NOT each individual segment. This keeps timing continuous — no caption restart at segment cuts.

3. **Style picking**:
   - User says nothing specific about style → omit `--style` (uses `default`: 5 words/line, font 65, bottom-positioned, yellow highlight). Good baseline for talking-head, narration, mixed content.
   - User says "TikTok-style" / "creator selfie" / "single word pop" → `--style tiktok`.
   - User says "clean", "professional", "minimal", "editorial" → `--style minimal`.
   - User says "music video", "lyric video", "karaoke" → `--style karaoke`.
   - User says "punchy", "attention grab", "hook style", "viral" → `--style reels-pop`.
   - User specifies custom font / color / size → apply preset + override flags.

4. **Language**: always specify `--language` for non-English content. Default is `en`. Common: `tr`, `es`, `fr`, `de`, `it`, `pt`, `nl`, `ja`, `zh`, `ko`. Any 2-letter or 3-letter ISO code accepted.

5. **Duration**: auto-detected via `ffprobe` for local files. For remote URLs, pass `--duration-seconds <n>` explicitly.

6. **Plan summary** must mention subtitle as a separate cost line:
   > "Plan: 3-segment UGC video (Seedance R2V) → 1500cr + auto-subtitle on final 36s concat → 36cr. Total: 1536cr. OK?"

## What NOT to do

- ❌ Don't let Seedance burn its own subtitles via the prompt. Always include the `No subtitles, no captions, no on-screen text overlays` line in every Seedance prompt (per `no-music-no-subtitles.md`).
- ❌ Don't subtitle each multi-segment piece individually — subtitle the final concat for continuous timing.
- ❌ Don't set `--words-per-line 1` for `minimal` style (defeats the purpose; that's a `tiktok` style choice).
- ❌ Don't pass a non-Google-Font name to `--font` — fal pulls from fonts.google.com only. If the user wants a custom font, fall back to a similar Google Font.

## Pipeline integration (future)

For a one-command full UGC ad with captions, the `--auto-subtitle <style>` flag on `video generate` will chain auto-subtitle automatically after the final concat. Use `--no-auto-subtitle` to opt out if needed. (Status: planned — not yet shipped at time of writing.)
