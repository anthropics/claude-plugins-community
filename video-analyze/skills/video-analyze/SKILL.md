---
name: video-analyze
description: Watch and analyze video files or video URLs (YouTube, Vimeo, TikTok, Twitter, direct .mp4, etc.). Use whenever the user gives you a path to a video file, a video URL, or asks you to summarize / transcribe / find code in / describe a video. Independent of any external AI — runs ffmpeg + whisper.cpp locally, then Claude reads the extracted frames and transcript.
---

# Video analysis

## When to trigger

Activate automatically when the user:
- Gives you a path ending in `.mp4`, `.mov`, `.webm`, `.mkv`, `.avi`, `.m4v`, or `.flv`
- Pastes a URL from YouTube, Vimeo, TikTok, Twitter/X, Instagram, Twitch, Reddit, Facebook, or a direct video file URL, AND clearly wants it analyzed (e.g. "what's in this", "summarize", "watch this", "transcribe", "find the code shown")
- Explicitly asks you to "watch", "analyze", "transcribe", or "summarize a video"

Do NOT trigger on every pasted URL — only when the user's intent is clearly to have the video understood.

## How to run

1. Call the helper script. It extracts frames + transcript and prints the working directory:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/video-analyze/analyze.sh" "<input>"
   ```

   Useful flags:
   - `--max-duration 1800` raise/lower the 60-min cap
   - `--fps 1/5` override adaptive frame sampling
   - `--hq` use 720p instead of 360p (slower; only when fine visual detail matters)
   - `--force` ignore cache and redo

2. The script prints the artifact directory on its last line. It contains:
   - `frames/frame_*.jpg` — sampled stills, read these with Read
   - `transcript.txt` — speech transcript (from YouTube captions if available, else whisper)
   - `metadata.json` — duration, resolution, frame count, transcript source
   - `.done` — sentinel so the next call is cached

3. Read `metadata.json` first to understand scope, then sample frames + transcript intelligently:
   - Short video (< 30s): read every frame
   - Medium (< 5 min): read evenly spaced frames + skim transcript
   - Long: rely mostly on transcript, sample a few frames for context

4. Answer the user's question by synthesizing across frames and transcript. **Cite frame numbers and timestamps** so they can spot-check (e.g. "around `frame_0007.jpg` / 0:34 in the transcript, the terminal shows…").

## Output modes — pick based on the user's question

- **Summary** (default if they just say "what's this"): 3–6 sentences describing what happens and what it's about.
- **Transcript**: surface the transcript verbatim or cleaned.
- **Code/text extraction**: if frames show terminals, IDEs, or whiteboards, transcribe the visible text/code carefully. Flag uncertainty.
- **Action items / steps**: for tutorials/demos, list the sequence of actions shown.
- **Specific question**: answer just what they asked, using only relevant frames.

## Failure modes to handle

- **Missing dependency** (exit 3): tell the user which tool is missing and the one-line install command for their OS (see `scripts/check-deps.sh`).
- **Duration cap exceeded** (exit 5): tell the user the duration and offer to re-run with `--max-duration` or `--force`.
- **yt-dlp failure** (exit 4): show `yt-dlp.log` tail. Common causes: geo-block, login required, dead link.
- **Empty transcript**: video may be silent, music-only, or whisper model failed to download. Note this and rely on frames.
- **No frames extracted**: corrupted video or unsupported codec — surface the ffmpeg error.

## Privacy

All processing is local. Nothing is uploaded. Artifacts live in `$TMPDIR/claude-video-analyze/<hash>/` — mention this to the user if they ask, and offer to clean up with `rm -rf` after.
