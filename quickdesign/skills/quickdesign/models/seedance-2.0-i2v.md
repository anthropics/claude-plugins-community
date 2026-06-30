---
slug: seedance-2.0-i2v
category: video_generate
provider: fal | kie
status: niche
description: Seedance 2.0 Image-to-Video. Niche model — almost never the right pick for UGC. Defaults must come from `seedance-2.0-r2v` instead. This card exists so the agent recognizes when (rarely) i2v is the right call and can document why.
---

## When to use

**Almost never.** R2V is the universal default for everything UGC. Use i2v ONLY when:

- The user has named `seedance-2.0-i2v` explicitly ("use i2v")
- `seedance-2.0-r2v` is unavailable / inactive in the registry (check `quickdesign video models`)

There is **no scenario** where i2v is "simpler" enough to justify silently picking it over R2V. R2V accepts a single `--reference-image` cleanly — it works exactly like i2v's `--image` from the user's perspective, and it preserves all the primitives the skill depends on:

- `@Image1` reference grammar
- Repeatable `--reference-image` for multi-product
- `--reference-audio` voice continuity for multi-segment

i2v silently forfeits all three.

## Capabilities (for reference)

```bash
quickdesign cost seedance-2.0-i2v -d 12 -r 1080p
quickdesign video models | jq '.data[] | select(.slug=="seedance-2.0-i2v")'
```

- Single `--image` input only — no `image_urls[]` array, no `audio_urls[]`, no `video_urls[]`
- Same duration grid (4–15s), same resolutions, same aspect ratios
- Native audio: yes, but no voice continuity primitive

## How to apply

Don't pick this model autonomously. If considering it, either:
1. Default to `seedance-2.0-r2v` instead, OR
2. Route through `AskUserQuestion` and let the user explicitly pick i2v.

See `../SKILL.md` cardinal rule #0.
