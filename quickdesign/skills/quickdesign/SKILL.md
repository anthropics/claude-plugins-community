---
name: quickdesign
description: Use the `quickdesign` CLI to generate AI media — UGC promo videos, image edits, product creatives, video upscales — through Seedance, Kling, Sora2, Nano Banana, and GPT Image. Invoke this skill whenever the user asks for a talking-avatar video, multi-segment ad / promo / explainer, image edit (object swap, angle change, state change), product photoshoot, or video upscale via QuickDesign.
---

# QuickDesign CLI skill

This skill teaches Claude how to plan and execute AI media generation through the `quickdesign` CLI. The CLI wraps QuickDesign's hosted models (Seedance 2.0 R2V/I2V, Kling, Sora 2, Nano Banana, GPT Image, video upscale) so a Claude session can produce videos and images directly from Bash without managing API keys, polling, or storage upload.

## When to invoke

- **Talking-avatar / UGC video** — "make a 30-second ad where this person says X", "convert this script to a video", "create a creator-selfie clip"
- **Multi-segment promo / explainer** — anything where total speech is >15s (single Seedance segment cap) or where the user wants angle cuts / framing progression
- **Image edit / generation** — angle change, state change, product on white background, lifestyle composite, brand-kit-styled creatives, multi-product reference composition
- **Video upscale** — bring 720p / 1080p output to 1080p / 4K
- **Bulk / batch creative production** — "do this for each of these 5 product photos"

Do NOT use for: pure text generation, code edits, search — those have their own tools.

## Cardinal rules (read first, every time)

These apply to every generation. Breaking any of them produces visible defects.

0. **Default video model = `seedance-2.0-r2v` for ANY UGC / talking-avatar / promo / explainer / multi-scene work, regardless of duration or segment count.** Don't downgrade to `seedance-2.0-i2v` because the script is "short enough" — R2V handles 4-15s single-shot just as well as multi-segment, and going through R2V from the start preserves every primitive this skill depends on (`@Image1` references, multi-`--reference-image`, `--reference-audio` voice continuity). Switch off R2V only on **explicit user opt-in** ("use Sora 2") or if R2V is unavailable in the registry.

   ⚠️ **The name "i2v" (image-to-video) is misleading.** R2V also accepts a single-image-to-video flow — just pass one `--reference-image`. Don't pick i2v because the task is "image-to-video as English". An agent reasoning chain like *"user wants to animate static images → image-to-video → therefore seedance-2.0-i2v"* is the silent regression this rule exists to prevent. Even when you're animating a single banana edit with no speech and no multi-ref needs, R2V is still the default — i2v adds nothing and forfeits the primitives if the next iteration of the task DOES need them.

   See `models/seedance-2.0-r2v.md`.

1. **Use `@Image1` / `@Audio1` / `@Video1` reference labels in prompts, and pass EVERY relevant photo as a separate reference.** Both `nano-banana-2` (image edit) and Seedance 2.0 R2V (video) accept multiple `--reference-image` flags. If the user uploaded a product from two angles, pass both — describing the second one in prose is a regression. Don't re-describe the person, wardrobe, or product in words; that competes with the reference image and causes drift.

   ❌ **Wrong** — verbose verbatim re-description of `@Image1`:
   ```
   Authentic UGC photo of the woman from the reference (long wavy brown
   hair, natural glowy makeup, glossy peach-coral lips, gold hoop earrings,
   pearl choker, soft smile), wearing the beige suede sneakers from the
   second reference, in a cozy minimal bedroom...
   ```
   Banana already SEES her hair / makeup / lips / jewelry in `@Image1` and the sneaker color / silhouette / sole in `@Image2`. Re-describing them tells the model "ignore the references, paint from this prose" — competes with the visual anchor and causes drift.

   ✅ **Right** — labels do the work, prose only describes what's NEW:
   ```
   Edit @Image1: change pose to iPhone mirror selfie. Add a white ribbed
   tank top + oversized baggy jeans. Sneakers matching @Image2 visible at
   the bottom of the frame. Keep face, hair, makeup, jewelry, and
   lighting unchanged from @Image1.
   ```

   See `references/multi-reference-pattern.md` and the per-model card under `models/`.

2. **Multi-segment voice continuity = `--reference-audio` from Seg 1's extracted audio.** Generate Seg 1 first → `ffmpeg -vn -acodec libmp3lame` extracts audio → pass that mp3 as `--reference-audio` to Segs 2..N. Without this, every segment picks a different voice. See `references/voice-continuity.md`.

3. **Suppress the layered music bed and burned subtitles — minimal directive only.** Add two short lines to the prompt: `No music score.` and `No subtitles or on-screen text.` That's it. Do NOT enumerate ambient sounds you want to keep ("street noise, café chatter, espresso machine") — Seedance produces natural ambient on its own; over-prescribing makes audio feel scripted. See `references/no-music-no-subtitles.md`.

4. **For burned-in captions, use `quickdesign video subtitle` AFTER generation.** Never let the video model burn its own captions via the prompt — they hallucinate. The dedicated subtitle endpoint runs real ASR (ElevenLabs) and renders accurate karaoke-style captions. See `references/auto-subtitle.md`.

5. **Confirmation gates — pause before spending credits, even in auto mode.** Auto mode reduces friction for **low-cost reversible work** (file edits, research, planning). Paid AI generation is neither low-cost nor reversible — auto mode does NOT bypass these gates. Always:
   - **Plan summary BEFORE any video generation** (Type / Model / Duration / Cost / Script). Surface it, then either wait for explicit "go" (normal mode) OR proceed immediately while keeping the plan visible above the bash call so the user can kill the task before the spend completes (auto mode). The plan must arrive BEFORE the bash invocation, never after.
   - **Banana edit reference BEFORE feeding it into Seedance R2V** → show the edit, wait for visual approval. Banana ~12cr, Seedance ~250-500cr; a wrong reference auto-chained burns 50× the cost. This gate does NOT compress in auto mode.
   - See `references/confirmation-rules.md` for full auto-mode interplay.

6. **For *choice* gates use the `AskUserQuestion` tool, not free-form prose.** Model picker, transition style, resolution, banana edit approve / regenerate / cancel — call `AskUserQuestion` with a structured option list and put your recommendation FIRST with `(Recommended)`. See `references/confirmation-rules.md`.

7. **When avatar is supplied AND setting doesn't change, EDIT the avatar — don't regenerate.** Compose-style banana prompts ("Compose a vertical 9:16 UGC selfie frame...", "Generate a creator-selfie scene...") cause the model to render a fresh AI-look image inspired by the avatar — losing the source's lighting, grain, and lo-fi authenticity. The result feels synthetic instead of like a real creator's edited selfie. Use edit-style verbs (`Edit @Image1: add ...`, `Take @Image1 as-is and only change ...`, `Keep every pixel of @Image1 except [region]`), don't re-list scene tokens that the reference already shows, and strip quality-upgrade words ("photo-realistic", "studio quality", "8K") from the prompt — they trigger regen. See `references/avatar-edit-not-regenerate.md`.

8. **For UGC video, surface the speech-or-silent choice — don't pick silently.** "UGC video" is ambiguous: it could be a spoken creator clip (script-driven, voice + lip-sync) OR a motion-only beat (OOTD reveal, b-roll, animated stills with text overlays in post). Both are legitimate creative formats. The agent must NOT pick one silently:

   - **Strong signal toward SPOKEN** (just go): user wrote "talking-avatar", "creator says", "voiceover", "explainer", "ad with script", or supplied a script themselves. Build script → put in plan summary → generate with `generate_audio: true` and the quoted speech inline.
   - **Strong signal toward SILENT** (just go): user wrote "OOTD reveal", "motion only", "no audio", "B-roll", "Pinterest aesthetic", or wants a static-image animation reel.
   - **Ambiguous "UGC video" / "promo video" / "ad video"** — call `AskUserQuestion` with two options: spoken (with a draft 4-8 word hook) or silent + post-overlay text. Recommend whichever fits the user's brief better. Do NOT silently default.

   When SPOKEN is selected: never start generation without quoted speech in the prompt. If the user didn't supply one, draft 4-12s of dialogue that fits the brief, surface it in the plan summary, then proceed. Generating with a generic action prompt and no quoted speech produces silent video or model-babbled phonemes — wasted credits.

   See `references/script-and-duration.md` for word-count → duration math.

9. **Multi-segment plans STOP after Seg 1 for visual approval — don't fan-out Segs 2..N until the user confirms Seg 1 came out right.** Voice continuity locks Seg 1's audio into every subsequent segment via `--reference-audio`. If Seg 1 has the wrong voice, wrong avatar identity, mispronounced word, or off-brand framing, every parallel Seg 2..N inherits that defect. A 4-segment plan at ~250cr/segment = ~1000cr; auto-fanning out a broken Seg 1 burns ~750cr that didn't need to be spent.

   The flow is:
   1. Plan summary → user approves (Rule 5).
   2. Render Seg 1 only.
   3. **Surface Seg 1's video URL in the chat** + call `AskUserQuestion` with options:
      - **Looks good — render Segs 2..N** *(Recommended if Seg 1 is clean)*
      - **Re-render Seg 1** (adjust prompt / reference / duration)
      - **Cancel the multi-segment plan**
   4. Only on "Looks good" → fan out Segs 2..N in parallel with the extracted audio.

   This gate does NOT compress in auto mode. The Seg 1 → Seg N spend multiplier is the same regardless of how patient the user is. See `pipelines/ugc-video.md` for the canonical multi-segment flow.

10. **Camera stays put. Don't change angle / framing unless the user explicitly asks for it.** Documentary-style UGC (street interview, kitchen demo, founder POV, customer testimonial, vlog-style) reads as **one continuous camera point**, not a multi-angle cut sequence. Default to: same framing (e.g., mid-shot eye-level), same distance, avatar in roughly the same position across every segment. The "transition" between segments is the avatar's gesture / line / micro-expression — not an angle cut.

    ❌ **Wrong defaults** (silent regression — produces a "shot-by-Director-of-Photography" feel that destroys UGC authenticity):
    - Seg 1 mid-shot → Seg 2 over-shoulder → Seg 3 close-up
    - "Push in slowly on the speaker"
    - "Cut to product close-up on the punchline"
    - Each `nano-banana-2` segment ref using a different angle of the same person

    ✅ **Right default** (UGC authenticity preserved):
    - Same source frame or near-identical angle/lighting across every segment. Only the avatar's hand position, gaze, or expression changes between segments.

    Only switch to multi-angle when the user explicitly asks: "alternate angles each segment", "cinematic cut to close-up at the hook", "include an over-shoulder shot of the product", "studio-style multi-cam UGC". When unsure, ask via `AskUserQuestion`: *Fixed camera (recommended for documentary UGC) / Multi-angle (cinematic cuts).*

    See `references/first-frame-not-camera-motion.md` for the related rule about static framing vs. described camera motion.

11. **Audit ALL the references the user supplied — product alone is not enough for UGC.** When the brief is "make a UGC video for this product" and the user supplied ONLY a product photo, STOP before generating. Seedance R2V needs anchored references for: the **product**, the **avatar / creator** (face, build, vibe), and the **scene / location** (kitchen, bathroom, gym, sidewalk). Prose can describe the product in detail, but if you describe the avatar in prose only, Seedance will hallucinate a generic-looking person — usually a synthetic-feeling Caucasian woman in her 20s — and the scene will read as stock B-roll, not the brand's world. The result fails the "doesn't look made" bar.

    Before generation, audit the supplied media:
    - **Product image** — almost always present. Pass as `--reference-image` with prompt label `@Image1`.
    - **Avatar / creator image** — if user provided one, pass it as a separate `--reference-image` and label `@Image2`. If user didn't provide one, **call `AskUserQuestion`** before generating: *Upload a creator headshot / Pick from QuickDesign avatar library (5,000+ portraits) / Proceed with prose-described creator (synthetic-look risk).* Recommend "Pick from library" if the user is brief-only.
    - **Scene / location image** — if the user is filming a "kitchen scene", "bathroom mirror selfie", "office desk POV", etc., ask whether they have a reference photo of the actual room. Pass as `@Image3` if supplied.

    The Seedance R2V call should look like:
    ```bash
    quickdesign video generate --provider seedance \
      --reference-image product.jpg \
      --reference-image avatar.jpg \
      --reference-image scene.jpg \
      --aspect-ratio 9:16 --duration 12 --resolution 1080p \
      -p '@Image2 in @Image3, holds @Image1 toward camera. She says: "..." No music score. No subtitles or on-screen text.' \
      -o seg1.mp4 --wait
    ```
    `@Image1`/`@Image2`/`@Image3` labels do the heavy lifting; prose only describes the action and quoted speech. See `references/multi-reference-pattern.md`.

## Decision tree — which doc to open first

**By job type:**

| Request | Start here |
|---|---|
| UGC / talking-avatar / promo / explainer / multi-segment ad | `pipelines/ugc-video.md` → `models/seedance-2.0-r2v.md` |
| Image edit (angle, state, multi-product composition) | `models/nano-banana-2.md` → `references/multi-reference-pattern.md` |
| Cinematic single-shot, audio-quality-driven (4/8/12s) | `models/sora2-i2v.md` (only on explicit user opt-in) |
| Budget loop / non-spoken b-roll | `models/kling-3-pro.md` |
| Final video too low-res | `models/topaz-video-upscale.md` (run after concat) |
| Add captions to existing video | `references/auto-subtitle.md` |
| Brand not in Spy Brands library / 0 search results | `references/spybrands-add-on-miss.md` |
| User is on claude.ai (web) and asks about QuickDesign | `references/connecting-claude-ai-via-mcp.md` |
| Publish designs to Meta as ads / analyze own Meta ad performance | `references/deploy-meta.md` |

**By job phase:**

| Phase | Read |
|---|---|
| Plan: script / duration math, narrative beats | `references/script-and-duration.md`, `references/narrative-arc.md` |
| Pre-flight: which model is alive in the registry | `quickdesign video models`, `quickdesign cost --category video` |
| Per-segment reference choice | `references/multi-reference-pattern.md`, `references/narrative-arc.md` |
| Generation: prompt skeleton + gotchas for the model you picked | `models/<slug>.md` |
| Quality gates: banana anatomy check, plan-summary approval | `references/confirmation-rules.md` |
| Post-processing: subtitle, upscale | `references/auto-subtitle.md`, `models/topaz-video-upscale.md` |

## Discover at runtime

The model registry is DB-driven and changes over time (new providers, retired versions, repriced tiers). **Don't hardcode model assumptions** — query the registry first when picking between alternatives.

```bash
quickdesign video models                            # active video models
quickdesign image models                            # active image-edit models
quickdesign cost                                    # all models, grouped by category
quickdesign cost --category video
quickdesign cost <slug> -d <duration> -r <resolution>   # exact compute for one model + params
```

When a new model lands that's better-fit than the current default, drop a new file in `models/<slug>.md` (copy the format from any existing card) and update the cardinal rule #0 / decision tree if the model becomes the new universal default.

## Quick start — common commands

```bash
# Auth (one-time, browser flow)
quickdesign auth login

# Image edit — angle change / state change / multi-ref product composition
quickdesign image generate \
  --model nano-banana-2 \
  --reference-image ~/path/to/avatar.jpg \
  --reference-image ~/path/to/product.jpg \
  --aspect-ratio 9:16 --resolution 2K \
  -p "@Image1 holds a product matching @Image2 exactly. ..." \
  -o ~/output.png --wait

# Single Seedance R2V (≤15s spoken script — still R2V, not i2v)
quickdesign video generate \
  --provider seedance \
  --reference-image ~/path/to/source.png \
  --aspect-ratio 9:16 --duration 12 --resolution 1080p \
  -o ~/output.mp4 --wait \
  -p '@Image1 in the same setting. <action>. He/She says: "..." No music score. No subtitles or on-screen text. Vertical 9:16 format.'

# Multi-segment Seedance R2V with voice continuity
# 1) Generate Seg 1 (sequential, native audio)
quickdesign video generate --provider seedance --reference-image seg1.png \
  --duration 12 --aspect-ratio 9:16 --resolution 1080p \
  -p '...' -o seg1.mp4 --wait
# 2) Extract Seg 1 audio
ffmpeg -y -i seg1.mp4 -vn -acodec libmp3lame -q:a 2 seg1-audio.mp3
# 3) Segs 2..N in parallel, each with --reference-audio
quickdesign video generate --provider seedance \
  --reference-image seg2.png --reference-audio seg1-audio.mp3 \
  --duration 12 --aspect-ratio 9:16 --resolution 1080p \
  -p '...' -o seg2.mp4 --wait &
# 4) Concat (mux-only, no quality loss)
printf "file 'seg1.mp4'\nfile 'seg2.mp4'\n" > /tmp/concat.txt
ffmpeg -y -f concat -safe 0 -i /tmp/concat.txt -c copy final.mp4

# Auto-subtitle (karaoke style, post-generation)
quickdesign video subtitle ./final.mp4 \
  --style tiktok --language en \
  -o ./final-subbed.mp4 --wait
```

## File index

```
SKILL.md                           ← you are here: cardinal rules + decision tree + nav
references/                        ← model-agnostic concepts (read for principles)
   confirmation-rules.md           ← gates, AskUserQuestion convention, anatomy self-check
   multi-reference-pattern.md      ← @Image1/@Image2/@Image3 multi-ref usage
   avatar-edit-not-regenerate.md   ← edit-style verbs, don't compose-regen the avatar
   spybrands-add-on-miss.md        ← when `spy brands --search` returns 0: confirm + resolve FB page + `spy add`
   connecting-claude-ai-via-mcp.md ← claude.ai (web) users: how to connect via MCP, what's available vs. CLI-only
   deploy-meta.md                  ← `meta` commands: publish designs as PAUSED Meta ads + insights/report/radar analytics
   voice-continuity.md             ← --reference-audio across multi-segment
   no-music-no-subtitles.md        ← minimal music + subtitle suppression
   auto-subtitle.md                ← post-generation captions (real ASR, not model-burned)
   narrative-arc.md                ← per-segment reference decision tree
   script-and-duration.md          ← word count → segment math, gender-neutral defaults
   first-frame-not-camera-motion.md ← why "static hold" / "slowly zooms" cause defects
   brand-and-moderation.md         ← brand-kit conventions, content moderation
pipelines/                         ← multi-step workflows (model-agnostic where possible)
   ugc-video.md                    ← canonical multi-segment talking-avatar method
models/                            ← per-model reference cards (gotchas + prompt skeletons)
   seedance-2.0-r2v.md             ← DEFAULT for UGC / promo / talking-avatar
   seedance-2.0-i2v.md             ← niche; explicit user opt-in only
   nano-banana-2.md                ← default for image edit + multi-ref product composition
   sora2-i2v.md                    ← cinematic single-shot, opt-in
   kling-3-pro.md                  ← budget alternative for non-spoken b-roll
   topaz-video-upscale.md          ← post-pipeline upscale
```

When the user asks for something specific, jump directly to the relevant file in `models/` or `pipelines/`. The cardinal rules above are the only thing that should always be in active context.
