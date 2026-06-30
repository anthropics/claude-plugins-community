---
slug: topaz-video-upscale
category: video_upscale
provider: fal
status: post-pipeline
description: Topaz video upscale. Run AFTER final concat to bump 720p / 1080p generation output to 1080p / 4K. Per-second pricing with optional 60fps multiplier. Don't run upscale per-segment — generate at native target resolution, then concat, then upscale once.
---

## When to use

- Final concatenated video is too low-res for the delivery channel (1080p reel posted to a platform that prefers 4K masters)
- Source footage is older / lower res and you want to clean it up before publish
- Text-heavy / detail-heavy frames need extra crispness

Don't use as a substitute for generating at 1080p in the first place. Seedance R2V at 1080p produces a cleaner master than 720p + Topaz upscale, in most cases.

## Hard facts (live)

```bash
quickdesign cost topaz-video-upscale -d 24 -r 4k
quickdesign cost topaz-video-upscale -d 24 -r 4k --fps60
quickdesign video models | jq '.data[] | select(.slug=="topaz-video-upscale")'
```

- **Cost**: `per_second` × resolution. `720p=1cr/s`, `1080p=2cr/s`, `4k=8cr/s`.
- **60fps multiplier**: ×2 if `--fps60`. Use ONLY if downstream playback is genuinely 60fps; most social platforms are 30fps and the bump is wasted.
- **Sibling**: `bytedance-video-upscale` is similar with a different cost ladder + a `pro_multiplier`. Compare via `quickdesign cost --category video_upscale`.

## Pipeline placement

Always **run after the final concat**, not per-segment:

```bash
# generate segments at native resolution
quickdesign video generate ... -o seg1.mp4
quickdesign video generate ... -o seg2.mp4

# concat (mux-only, no quality loss)
ffmpeg -f concat -safe 0 -i concat.txt -c copy final.mp4

# upscale ONCE
quickdesign video upscale ./final.mp4 \
  --provider topaz --resolution 4k -o ./final-4k.mp4 --wait
```

Per-segment upscaling wastes ~Ncr × duration and can introduce inter-segment quality mismatches.

## Gotchas

1. **Doesn't help with motion blur / shake** — purely a resolution upscale. Pre-existing motion artifacts stay.
2. **Doesn't add detail** — invents plausible textures from neighborhood context. Faces hold up reasonably; fine product detail (engraving, label text) can soften.
3. **60fps inflation rarely worth the 2× cost** for short-form social. Stay at native 24/30fps unless the platform requires otherwise.

## Cross-references

- UGC final concat step → `../pipelines/ugc-video.md` (final concat section)
- Subtitle post-processing (run BEFORE upscale or after, doesn't matter) → `../references/auto-subtitle.md`
