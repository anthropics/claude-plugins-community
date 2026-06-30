---
slug: kling-3-pro
category: video_generate
provider: fal
status: budget
description: Kling 3 Pro. Cinematic motion model. Cheaper than Seedance 2.0 R2V at most durations, but no reference grammar, no audio-continuity primitive, no native voice generation matching Seedance quality. Use as a budget alternative for simple loops / b-roll / non-spoken-script clips, or when user explicitly asks for Kling.
---

## When to use

- Budget-tight job, simple animation, no spoken voiceover
- Non-UGC b-roll: product rotation, atmospheric loop, abstract motion
- User explicitly named Kling
- Voice continuity / multi-product reference fidelity is NOT required

Don't use for spoken-script UGC — Kling's TTS is weaker than Seedance's native voice and there's no `--reference-audio` continuity. For talking-avatar work always start at Seedance R2V.

## Hard facts (live)

```bash
quickdesign cost kling-3-pro -d 5
quickdesign video models | jq '.data[] | select(.slug=="kling-3-pro")'
```

- **Duration grid**: 3..15s (per-second lookup, see `quickdesign cost kling-3-pro -d <n>`)
- **Cost**: `duration_lookup` — discrete cost per duration; check before submitting.
- **Reference grammar**: NONE. Single `--image` input only.
- **Audio**: yes via `generate_audio`, but voice character generally weaker than Seedance for speech.

## Compact prompt skeleton

```
<scene description>. <action / motion verbs OK here, unlike Seedance>.
<aspect ratio> format.
```

Camera-motion verbs ("slowly zooms in", "pans left", "tracking shot") work better here than in Seedance — Kling produces cleaner cinematic motion when explicitly directed.

## Sibling models in the Kling family

- `kling-3-standard` — cheaper, simpler animation. Use for loops where Pro's quality bump isn't worth it.
- `kling-2.6-pro`, `kling-2.1-pro`, `kling-2.1-standard` — older versions, retained for users with prior workflows. Default to `kling-3-*` for new work.
- `kling-o1-edit` — fixed-cost edit operation (64cr), niche use.

Compare via `quickdesign cost --category video | grep kling`.

## Gotchas

1. **No `audio_urls` continuity** — every segment generates a fresh voice. Multi-segment Kling is voice-incoherent unless you use TTS + lipsync external pipeline.
2. **No `@Image1` reference grammar** — descriptive prompts carry more weight than with Seedance R2V. Be more verbal.
3. **Subtitle / music defaults are less aggressive** than Seedance, but still add `No music score.` + `No subtitles.` to be safe.

## Cross-references

- For talking-script UGC use Seedance R2V instead → `./seedance-2.0-r2v.md`
- Voice continuity strategies → `../references/voice-continuity.md`
