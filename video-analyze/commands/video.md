---
description: Analyze a local video file or video URL (YouTube, Vimeo, TikTok, etc.). Extracts frames + transcript locally with ffmpeg + whisper, then summarizes.
argument-hint: <path-or-url> [question]
---

The user wants you to analyze a video. The input is:

`$ARGUMENTS`

Use the `video-analyze` skill:

1. Run the analyzer:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/video-analyze/analyze.sh" "$ARGUMENTS"
   ```

   (if the user passed a question after the path/URL, split it off — only the first whitespace-separated token is the input; the rest is the question to answer.)

2. Read `metadata.json` from the printed working directory.

3. Read enough frames and the transcript to answer well — see the skill for the sampling strategy.

4. If the user asked a specific question, answer that. Otherwise give a 3–6 sentence summary plus a "want more?" prompt offering: full transcript, code/text extraction from frames, action items, or specific timestamp lookup.

5. Cite frame numbers and timestamps so the user can verify.

If the analyzer exits non-zero, surface the error clearly and suggest the fix (install command, raise `--max-duration`, etc. — the skill documents each exit code).
