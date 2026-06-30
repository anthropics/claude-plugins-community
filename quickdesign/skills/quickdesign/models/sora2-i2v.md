---
slug: sora2-i2v
category: video_generate
provider: kie
status: opt-in
description: Sora 2 Image-to-Video. Cinematic single-shot model — cleaner native audio mix than Seedance, but no reference grammar (@Image1) and no audio-continuity primitive. Use ONLY when the user explicitly opts in for audio quality, OR when the brief is "cinematic single-shot" and not multi-segment UGC.
---

## When to use

- User explicitly says "Sora 2", "use Sora", "Sora kalitesi" — audio fidelity is the explicit driver
- Single-shot brief with one of the three durations (4 / 8 / 12s), no multi-segment cuts needed
- Voice continuity across segments is NOT required (Sora 2 doesn't accept `audio_urls`)

Don't use as a default substitute for Seedance R2V on multi-segment UGC — voice character will drift across cuts because Sora 2 generates a fresh voice per call. R2V's `--reference-audio` is the only way to lock voice character across multiple segments today.

## Hard facts (live)

```bash
quickdesign cost sora2-i2v -d 8
quickdesign video models | jq '.data[] | select(.slug=="sora2-i2v")'
```

- **Duration grid**: discrete `4`, `8`, `12` seconds only. No 5s, 6s, 9s, etc. Plan accordingly.
- **Cost** is duration_lookup, not per-second: `4s=40cr`, `8s=65cr`, `12s=95cr`. Linear-ish but cheaper per second than Seedance 2.0 R2V at 1080p.
- **Aspect ratios** + resolutions: see registry.
- **Native audio**: yes, generally cleaner mix than Seedance (less aggressive music bed).
- **Reference grammar**: NONE. No `@Image1`/`@Image2` labels. Single `--image` only.

## Compact prompt skeleton

```
<scene description with subject + setting + lighting + mood>.
The person says: "<verbatim quoted speech>".
No music score. No subtitles or on-screen text.
<aspect ratio> format.
```

Note: there's no `@Image1` to lean on, so subject / setting description in the prompt does carry weight here (unlike R2V where verbose descriptions dilute the reference). Keep it descriptive but tight.

## Gotchas / failure modes

1. **Less aggressive music bed than Seedance** — but it can still layer one. Keep the `No music score.` line.
2. **Subtitle hallucination** — same as Seedance, add `No subtitles or on-screen text.`
3. **No reference labels** means reference image is hint-only, not anchor — small details (shirt color, room props) sometimes reinterpret. Less reliable for product-fidelity work; for products use Seedance R2V.
4. **Voice character is fresh per call** — if you generate a 12s ad with Sora 2 and want a follow-up segment, you can't lock the voice. The follow-up must be either (a) standalone with no continuity expectation, (b) generated as a single longer Sora call, or (c) switched to Seedance R2V.

## Cross-references

- Multi-segment voice continuity needs Seedance R2V → `./seedance-2.0-r2v.md`
- Music + subtitle suppression rules → `../references/no-music-no-subtitles.md`
- Confirmation gates before paid generation → `../references/confirmation-rules.md`
