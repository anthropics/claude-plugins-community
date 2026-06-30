---
name: UGC video pipeline (canonical) — multi-segment Seedance R2V with voice-continuity audio_urls reference
description: The official method for producing talking-avatar / UGC promo videos via the QuickDesign CLI. Multi-segment Seedance 2.0 R2V calls; voice continuity is enforced by always passing segment 1's extracted audio as `--reference-audio` to all subsequent segments. Two transition styles supported on top of voice-continuity — angle-cut (nano-banana-2 reference edits) or framing-progression (same source image, only middle segments get explicit closer framing). Segments are concatenated with ffmpeg `-c copy`.
---

This is **the** method for talking-avatar UGC video production. Use it for any spoken-script video, regardless of total length.

## Model picker

**Default model: `seedance-2.0-r2v`** (Seedance 2.0 reference-to-video). Best-fit for this pipeline because it's the only currently-active model that supports all four primitives this method depends on:

1. Reference label syntax (`@Image1`, `@Image2`) — anchors identity + setting consistency without verbose verbatim descriptions
2. Audio reference (`audio_urls`) — locks voice character across multi-segment outputs without TTS chains
3. Integer duration grid 4–15s — matches natural speaking-segment lengths (~30 words / 15s @ 2 wps)
4. Reasonable price for iteration (~440-520cr per 11-13s segment with audio)

When a new model that supports the same primitives lands (Seedance 3, Veo 3 with audio refs, Sora 3, etc.), update this picker to name it and call out where it diverges. Until then this whole doc assumes Seedance 2.0 R2V.

**Pre-flight check** (the agent should do this for non-trivial requests):

```bash
quickdesign video models | jq '.data[] | select(.slug | contains("r2v") or contains("v2v"))'
```

If `seedance-2.0-r2v` is no longer in the list, the registry has moved on — pick the closest replacement and the rest of this pipeline still applies (only the syntax details in `../models/seedance-2.0-r2v.md` need adjusting, or a new model card needs to be added).

**Length is NOT a reason to switch off R2V.** R2V is the universal default for UGC across the entire 4-15s grid, single- and multi-segment alike. A short single-shot script does not justify dropping to `seedance-2.0-i2v` — passing one `--reference-image` to R2V is functionally identical to passing `--image` to i2v from the user's perspective, and it preserves every primitive this pipeline depends on (`@Image1`, `--reference-audio`, multi-`--reference-image`). Going to i2v for a short clip is a downgrade with no upside.

**When to deviate from the default:**

| Situation | Use instead | Why |
|---|---|---|
| User explicitly wants Sora 2 audio quality (cinematic single-shot, 4/8/12s) | `sora2-i2v` | Native mix is cleaner; voice-continuity strategy changes (no `audio_urls` available) |
| User explicitly opts into i2v, OR `seedance-2.0-r2v` not in registry | `seedance-2.0-i2v` | Only override the universal R2V default on explicit user opt-in — never silently |
| Budget-tight, simple loop, no voice / no product fidelity needed | `kling-2.1-standard` | Cheaper but no `@Image1` refs, no `audio_urls` — single segments only |
| Already-rendered video needs new caption | `fal-auto-subtitle` | Post-processing only, see `../references/auto-subtitle.md` |
| Generated video is too low-res | `topaz-video-upscale` / `bytedance-video-upscale` | Run after final concat — see `../models/topaz-video-upscale.md` |

For full per-model gotchas / prompt skeletons / failure modes, jump to the model card:
- `../models/seedance-2.0-r2v.md` — the default; see this for prompt syntax
- `../models/sora2-i2v.md` — when audio quality is the explicit driver
- `../models/kling-3-pro.md` — budget alternative for non-spoken b-roll
- `../models/seedance-2.0-i2v.md` — almost never the right pick (here for completeness)

The rest of this doc (segment planning, voice continuity, concat) is model-agnostic. The Seedance-specific bits live in `../models/seedance-2.0-r2v.md` so swapping models in the future is a localized edit.

**When more than one model is viable** for the request (e.g. user said "I want Sora 2 for the audio quality" on a ≤12s single-shot brief), don't pick silently — use the `AskUserQuestion` tool to surface the tradeoff with `seedance-2.0-r2v` marked `(Recommended)` first. Don't offer `seedance-2.0-i2v` as a default-tier alternative; only surface it if the user named it themselves. See `../references/confirmation-rules.md#use-askuserquestion-for-structured-choice-gates` for the exact pattern.

## Method

1. **Plan the segments.** Count script words. Each Seedance 2.0 segment is integer 4-15s and fits ~30 words at 2 wps natural pace. Divide the script at sentence/beat boundaries so each segment lands tight (no padding). The final segment may be shorter (e.g. 8s for a punchy CTA).

2. **Pick a transition style:**

   **(a) Plain talking-head UGC — DEFAULT** for service explainers, creator selfie content, casual reviews. **Single reference image** for every segment. No image edits, no angle changes. Voice continuity locked via `--reference-audio` (Seg 1 audio → Segs 2..N). Each segment's prompt describes its own action beat; Seedance produces natural variation (gesture, gaze drift, micro-pose) from the same anchor — enough variety for cuts to feel intentional in casual UGC. Cost: 0 image edits, just N× R2V.

   **(b) Angle-cut transitions** — for podcast / editorial / cinematic / multi-shot storytelling. Use when content has deliberate visual beats benefiting from angle changes (wide-front → 3/4 side → close mid-shot front), or when the user explicitly asks for "different angles". Generate angle-shifted reference images via nano-banana-2 for Segs 2..N. Cost: ~24cr per edit at 2K (default) or ~48cr at 4K (when product detail matters).

   **(c) Framing-progression transitions** — opt-in only. Same source for every segment; middle segment gets explicit "Medium close-up framing" line. Use when user wants zoom-in/out feel without image edits.

   ### Decision rule

   - User says "plain UGC" / "talking head" / "service explainer" / casual creator selfie → **(a) single ref**.
   - User says "podcast" / "cinematic" / "editorial" / "different angles" / "ikinci açı" → **(b) angle-cut**.
   - Reference image visually carries scene-narrative weight (editorial pose, prop interaction, dramatic lighting) → **(b) angle-cut** likely better even if user didn't say so explicitly; surface the choice in the plan summary so they can switch.
   - State change required (mouth empty when source has crystal, etc.) → must use per-segment image edits regardless of style.

   **Don't write camera-motion verbs in any prompt** ("slowly zooms in", "pulls back", "static hold"). Seedance produces natural micro-motion (breathing, head turns, gestures) on its own. See `../references/first-frame-not-camera-motion.md`.

3. **Decide per-segment reference images** based on what each segment NEEDS visually vs. what the source reference shows. See `../references/narrative-arc.md` for the full decision tree. Quick version per segment:
   - **Pure talking-head, no state change** → reuse source reference, 0 edits.
   - **Style (a) angle-cut** → generate angle-shifted reference via nano-banana-2 (~24cr at 2K each).
   - **Significant state change vs. source** (e.g. mouth empty when source shows mouth full, glasses off when source shows them on) → **MUST generate a state-matched reference via nano-banana-2** for that segment. The reference image overrides action-description "mouth is now empty" wording — verified empirically. Without a matched reference, expect visible state breaks at cuts.
   - **Borderline / ambiguous** → ASK the user before burning credit. Surface as a one-line question in the plan summary.

   For nano-banana-2 edit prompts:
   - **Use edit-style verbs, not compose-style.** `Edit @Image1: ...` not `Compose a vertical 9:16 frame...`. The compose form regenerates a fresh AI-look image and loses the avatar's lighting + grain + lo-fi authenticity. See `../references/avatar-edit-not-regenerate.md` for the verb library + setting-lock principle.
   - Pin identity: "Same person, same outfit, same setting, same lighting, same props."
   - State only the change: "Now without the crystal in mouth — mouth is closed and relaxed" / "3/4 side profile from the right" / "looking surprised, eyes wider".
   - Don't re-list scene tokens that the reference already shows — banana re-paints them and accumulates drift.
   - Strip quality-upgrade words from the prompt: "photo-realistic" / "studio quality" / "8K" trigger regen. For UGC, "match the lighting and grain of @Image1" is the right anchor.
   - Verify identity preservation before submitting the segment — re-generate the edit if the face drifted.

   **Resolution rule:**
   - **Default `--resolution 2K`** for talking-head / selfie / lifestyle (model is focal point). 1K leaves Seedance no headroom for clean 1080p output.
   - **Use `--resolution 4K`** when the video integrates a **product** (model holding/wearing/showcasing a specific product where label/texture/detail matters).
   - Cost ladder: 1K ≈ 12cr, 2K ≈ 24cr, 4K ≈ 48cr per edit.

4. **Generate Segment 1 first (sequential).** Standard Seedance R2V with native audio:
   ```bash
   quickdesign video generate \
     --provider seedance \
     --reference-image <seg1-ref.png> \
     --aspect-ratio 9:16 --duration <Ns> --resolution 1080p \
     --wait -o <seg1.mp4> \
     -p '<prompt using @Image1 reference syntax>'
   ```

   **Prompt syntax — use `@Image1` references, not verbatim identity descriptions.** See `../models/seedance-2.0-r2v.md` for the full rule + reference grammar. Standard skeleton:
   ```
   @Image1 in the same exact setting throughout.
   <one-sentence action/state for this segment>.
   He/She/The person says: "<verbatim quoted speech>".
   No music score. No subtitles or on-screen text.
   Vertical 9:16 format.
   ```

   `--generate-audio` is on by default. The "in the same exact setting throughout" pin handles location continuity. The two short audio/visual suppression lines stay minimal — don't enumerate ambient sounds you want. See `../references/no-music-no-subtitles.md`.

   **🛑 Seg-1 visual-approval gate (HARD STOP — applies to multi-segment plans).** After Seg 1 renders, do NOT proceed to audio extraction or Segs 2..N. Voice continuity locks Seg 1's audio into every subsequent segment, so a wrong voice / wrong avatar identity / mispronounced word / off-brand framing in Seg 1 multiplies the wasted spend by N. Single-segment plans skip this gate.

   The flow:
   1. Surface Seg 1's video URL in the chat (the `--wait -o <seg1.mp4>` step prints the public URL).
   2. Call `AskUserQuestion` with options:
      - **Looks right — render Segs 2..N** *(Recommended if Seg 1 is clean)*
      - **Re-render Seg 1** (tweak prompt, reference, duration, or quoted speech)
      - **Cancel the multi-segment plan**
   3. Only on "Looks right" → continue to step 5 (audio extract) and step 6 (parallel fan-out).

   This gate does NOT compress in auto mode. The Seg 1 → Seg N spend multiplier is the same regardless of how patient the user is. See SKILL.md cardinal rule #9.

5. **Extract Segment 1's audio** for voice continuity:
   ```bash
   quickdesign video extract-audio <seg1.mp4> -o <seg1-audio.mp3>
   # OR raw ffmpeg fallback:
   # ffmpeg -y -i <seg1.mp4> -vn -acodec libmp3lame -q:a 2 <seg1-audio.mp3>
   ```
   Mandatory whenever there's more than one segment. Single-segment videos skip this step.

6. **Generate Segments 2..N in PARALLEL**, each with `--reference-audio` set to seg1-audio.mp3:
   ```bash
   quickdesign video generate \
     --provider seedance \
     --reference-image <segN-ref.png>          # angle-cut: edited image; single-ref: same original \
     --reference-audio <seg1-audio.mp3>        # MANDATORY — voice continuity anchor \
     --aspect-ratio 9:16 --duration <Ns> --resolution 1080p \
     --wait -o <segN.mp4> \
     -p '<@Image1 + action + dialogue + no-music + no-subs + 9:16>'
   ```
   Each parallel call is one Seedance API hit — no TTS, no voice-clone, no lipsync overlay. Voice match happens natively inside Seedance.

7. **Concatenate.** Every segment is identical resolution / fps / codec / audio params (1080×1920, 24fps, H.264, AAC), so concat is mux-only — zero quality loss:
   ```bash
   quickdesign video concat <seg1.mp4> <seg2.mp4> <segN.mp4> -o <final.mp4>
   # OR raw ffmpeg fallback:
   # printf "file '<seg1.mp4>'\nfile '<seg2.mp4>'\n…\n" > /tmp/concat.txt
   # ffmpeg -y -f concat -safe 0 -i /tmp/concat.txt -c copy <final.mp4>
   ```

   If a segment was forced to a different resolution (e.g. credit-shortage 720p fallback), use the `concat` filter with re-encode instead.

## Why this beats legacy TTS+lipsync chains

- **Native audio per segment** — Seedance generates dialogue audio matching the quoted speech in the prompt, lip-synced inside the segment. No separate TTS + lipsync.
- **Voice continuity via `audio_urls` reference** — Seg 1's extracted audio is passed as `--reference-audio` to Segs 2..N, so Seedance natively matches the voice character across all segments. ZCR within ~0.001 of seg 1 baseline in validation.
- **Cost** — angle-cut style: 3× R2V + 2× image edit ≈ ~1500cr for a ~36s 3-act promo. Single-ref style: 3× R2V ≈ ~1450cr (no image edits).
- **Speed** — parallel-friendly: Seg 1 sequential (audio dependency), then Segs 2..N independent and run in parallel. Total wall time ≈ Seg 1 time + longest parallel segment + concat (~6-8 min for 36s output).
- **Visual coherence** — angle/framing changes are intentional cinematography. Cuts feel like director's choice. Voice character stays one person throughout.

## What NOT to do

- Don't propose any TTS + voice-clone + lipsync chain — retired in this skill. Use `audio_urls` instead.
- **Don't skip the `--reference-audio` step on multi-segment videos.** It's not optional — Seedance picks a different voice per call without it; cuts sound like 2-3 different people.
- Don't try to fit >30 words into a single Seedance segment — pacing collapses to chipmunk speed.
- Don't change wardrobe / setting / lighting between segments — only the angle / framing / facial expression. Anything else breaks visual continuity.
- Don't write camera-motion verbs in segment prompts. Describe the **first-frame composition** instead, or omit framing entirely on segments that should match the reference image's natural framing.
- Don't skip the identity check on angle-shifted reference images — nano-banana-2 occasionally drifts the face on hard angle changes; regenerate the edit before sending it to Seedance.
- **Don't use a "still life" reference for the closer segment.** If the reference shows the subject already in their final pose (lying down, fully relaxed, hands at sides), Seedance has nowhere to go — produces 11s of frozen output. Action-loaded references (subject mid-gesture) + motion-verb action lines give the closer life.
- **Don't use "last-frame-as-first-frame continuation" between segments.** PNG extraction is a re-encode → degraded color/sharpness; Seedance i2v then renders new video on top → compounded loss. Use angle-shifted nano-banana-2 reference instead.
