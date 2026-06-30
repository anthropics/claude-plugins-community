---
name: Script preservation, gender-neutral default, duration math (Seedance 4-15s every integer)
description: When the user supplies a script, include it verbatim as quoted speech in the prompt — don't paraphrase. Use gender-neutral subject (`The person`) unless reference image clearly shows otherwise. Seedance 2.0 supports every integer second from 4 to 15 — pick the tightest value that fits the segment's script (~2 wps). No need to round to 5/10/15 standard values. Cost scales linearly per second, so tight picking saves real credit.
---

When the user supplies a script (TTS-style narration text) and `--generate-audio` is on, keep the script verbatim inside the prompt as quoted speech.

## Gender-neutral default pattern

```
@Image1 in the same setting. Standing at the kitchen counter.
The person says: "<full script verbatim>".
No music score. No subtitles or on-screen text.
Vertical 9:16 format.
```

If the reference image OR the user's brief makes the gender unambiguous ("woman in glasses", "my female avatar"), use `She says: "..."` / `He says: "..."`. **Default to `The person says: "..."` when uncertain** — never assume male.

**Don't infer gender from filenames or first-name guesses.** A file called "alex_intro.png" might be male or female; the safer default is `The person`.

## Why these rules exist

1. **Don't strip the script** — Seedance / Kling / Veo3 with native audio generate dialogue audio matching quoted speech in the prompt. Paraphrasing into "speaking enthusiastically" produces ambient sounds or wrong content.
2. **Don't assume gender** — Reference images are user-supplied; could be male, female, neutral, or even non-human. Hardcoding `He says` is a real bug when the reference is a woman.

## Seedance 2.0 supported durations

**Integer seconds 4 through 15, every value allowed:** `4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15` (plus `"auto"` to let the model pick). Lower bound is 4 (NOT 1). No need to round up to 5/10/15 "standard" values — pick the tightest fit.

(Seedance 1.x legacy only accepts 5 or 10. Always use 2.0.)

## Cost is linear per second (~40cr/s at 1080p R2V)

Validated empirically:

| Duration | Cost (cr) |
|---|---|
| 4-5s | 160-200 |
| 8s | 320 |
| 11s | 440 |
| 12s | 480 |
| 13s | 520 |
| 14s | 560 |
| 15s | 600 |

So **tight duration picking saves real credit**: picking 11s instead of rounding to 15s saves 160cr per segment. For a 3-segment ad with tight durations averaging 12s instead of rounding to 15s, you save ~360cr per video.

## Duration picking algorithm (per segment)

1. Count words in this segment's script.
2. `raw = words / 2` (≈2 wps natural pace; 2.5 wps is faster but still natural)
3. `tight = ceil(raw)`
4. If `tight < 4` → bump to 4 (Seedance lower bound).
5. If `tight > 15` → this segment doesn't fit; split into two segments at sentence boundary.
6. Use `tight` as the duration.

**Add 1-2s padding only when:**
- The action description includes a meaningful gesture/beat AFTER the speech (e.g. "she says X, then turns to camera with a smile" — the turn needs ~1s)
- The closer segment needs visual breath to land the CTA (add 1s for the smile/wave/product hold to register)

Don't pad just to "be safe" — Seedance fits the audio to the requested duration and extra time becomes dead air or stretched mouth movement.

## Multi-segment splitting

If the total speech requires >15s:

```
total_seconds = ceil(total_words / 2)
segment_count = ceil(total_seconds / 15)
```

Distribute words to segments at sentence/beat boundaries — never mid-sentence. Each segment's duration follows the tight-pick algorithm above.

Example: 60-word script → 30s total speech. Split at sentence boundary into:
- Seg 1: 28 words / 14s (560cr)
- Seg 2: 32 words / 16s — exceeds, re-split as Seg 2 (16 words / 8s = 320cr) + Seg 3 (16 words / 8s = 320cr)

Total: 14s + 8s + 8s = 30s, 1200cr. Vs naive "round each to 15s": 1800cr. Saves 600cr.

## Plan summary template

Always include the duration math when surfacing the plan:

> "Script: 47 words → ~24s total speech → 2 segments. Seg 1: 24 words / 12s (480cr). Seg 2: 23 words / 12s (480cr). Total Seedance: 960cr. OK to proceed, or want to adjust duration / pacing?"

User can override (`"do it as 3 shorter segments"` / `"pad each to 15s"`) before any credit is spent.

## How to apply

1. If user gives a paragraph of speech-style text, ask once: "Should the character SPEAK this (audio on, dialogue-matched), or use it as direction only?" Skip the question on regen requests where intent is obvious.
2. Count script words per segment. Compute `ceil(words / 2)` seconds → that's the tight duration.
3. Use **`The person says: "..."`** unless the reference image / brief explicitly identifies gender. Don't infer gender from filenames or first-name guesses.
4. Wrap script verbatim inside the scene description; keep camera / lighting / framing context around the quote.
5. For pure action prompts (no spoken content), strip is fine — but check first.
6. Always show the duration + cost math in the plan summary so user can override before credits are spent.
