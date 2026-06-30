---
name: Seedance R2V audio_urls for voice continuity — never TTS+lipsync chain
description: Seedance 2.0 R2V accepts `audio_urls[]` (max 3 mp3/wav 2-15s each, ≤15MB) as a reference for the voice character it generates. For multi-segment videos that need consistent voice, extract segment 1's native audio and pass it as `--reference-audio` to subsequent segments. Do NOT orchestrate any TTS + voice-clone + lipsync pipeline for this — it's the wrong tool, costs ~2x more, and lipsync `sync_mode=cut_off` shrinks segments unpredictably.
---

When a multi-segment UGC video needs **voice continuity** across segments (so all speakers sound like one person), use Seedance R2V's native `audio_urls` reference parameter — not a TTS+lipsync chain.

## The right way

1. **Segment 1**: standard Seedance R2V with native audio. Script in prompt as quoted speech, `--generate-audio` on (default). This establishes "the voice".

2. **Audio extraction**:
   ```bash
   quickdesign video extract-audio seg1.mp4 -o seg1-audio.mp3
   # OR raw ffmpeg fallback:
   # ffmpeg -y -i seg1.mp4 -vn -acodec libmp3lame -q:a 2 seg1-audio.mp3
   ```
   Auto-uploads via CLI `--reference-audio` if local path.

3. **Segments 2..N**: pass the extracted audio as voice reference. Each segment's prompt has its own quoted speech; Seedance generates native audio for that segment but matches the voice character of the reference:
   ```bash
   quickdesign video generate \
     --provider seedance \
     --reference-image <same-or-different-image> \
     --reference-audio ~/path/to/seg1-audio.mp3 \
     -p "<scene + 'The person says: \"...\"' + no-music + no-subs + 9:16>" \
     --duration 12 --resolution 1080p --aspect-ratio 9:16 \
     --wait -o segN.mp4
   ```

4. **Concat** with `quickdesign video concat` (or `ffmpeg -c copy`) — same codec/resolution/audio params across segments because every segment is a fresh Seedance R2V output.

## Why NOT TTS + lipsync

A typical wrong-pipeline run:
- Seg 1: native Seedance R2V (correct)
- Then orchestrated: extract audio → voice-clone → TTS for segs 2/3 → 2 silent Seedance R2V → 2 lipsync → concat

Problems:
- Result lengths drift (35s instead of target 45s) because lipsync's `sync_mode=cut_off` truncates the silent video to TTS audio length.
- Cost: ~2x the right way (clone + TTS + lipsync = ~330 wasted credits per video).
- Wall-time: ~12-15 min vs ~6-8 min for the audio_urls approach.
- Multi-step orchestration risk: each step (clone → TTS → silent gen → lipsync) is a separate API call; one transient failure stalls the whole pipeline. `audio_urls` is one parameter on one API call.

## How to apply

- Whenever the user says "voice continuity" / "same voice" / "use this audio as reference" → think `--reference-audio`, not TTS.
- Plan template for multi-segment UGC:
  > "Voice-locked multi-segment: Seg 1 native audio → extract → pass to Segs 2..N as `--reference-audio` (Seedance R2V native voice matching). Cost ≈ N× R2V (no extra orchestration)."
- Reserve TTS + voice-clone + lipsync for cases where the user explicitly wants a SCRIPTED voice (e.g. dub a custom voice over Seedance video), not for character voice continuity.
- Constraints: `--reference-audio` repeatable, max 3 audio refs per call, mp3/wav, 2-15s each, ≤15MB.

## What `audio_urls` does and does not do

- **Does**: lock the voice character (timbre, pacing, accent feel) across segments.
- **Does not**: dictate WHAT is said in each segment. Each segment's prompt determines the words via quoted speech.
- **Does not**: replace the need for `--generate-audio` to be on. The reference is a character anchor; the segment still generates its own dialogue audio.
