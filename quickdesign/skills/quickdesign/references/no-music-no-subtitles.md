---
name: No music score, no burned subtitles — minimal directive only
description: Seedance R2V auto-layers a music bed under voiceover and burns hallucinated captions when prompts contain quoted speech. Add two short prompt lines to suppress both. Don't enumerate ambient sounds — over-prescribing makes audio feel scripted; Seedance produces natural ambient organically.
---

Seedance has two off-target defaults for UGC: it layers a music track under the voiceover, and it burns hallucinated subtitles into the pixels. Both kill authentic creator vibe. Both go away with two short prompt lines.

## The two lines

Add these to every R2V prompt with quoted speech (audio scope + visual scope, separate sentences):

```
No music score. No subtitles or on-screen text.
```

That's it. Don't expand. Don't list ambient sounds you want to keep ("street noise, café chatter, dish clatter, espresso machine, footsteps") — Seedance produces natural ambient on its own; enumerating it makes the model treat your list as a script and the audio comes out feeling staged. Trust the model.

## Skip these lines only when

- User explicitly asks for music ("with a beat", "cinematic score", "müzikli")
- User explicitly asks for burned captions ("with subtitles", "altyazılı", "TikTok-style text overlay")

## Subtitle pin for text-bearing reference images

If the reference image contains text (signage, product packaging, mural with words), Seedance sometimes redraws extracted text as a caption-style overlay. Add one explicit pin in addition to the standard line:

```
Only the text that exists in @Image1 itself — no additional text overlays.
```

## How to apply

1. Default: every R2V prompt with `--generate-audio` AND quoted speech gets the two short lines. Not the long version, not the ambient enumeration.
2. Multi-segment: include both lines in EVERY segment's prompt — voice continuity (`--reference-audio`) doesn't carry the music/subtitle suppression.
3. Plan summary: surface "music: off" and "subtitles: off" as flags the user can flip.
