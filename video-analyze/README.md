# video-analyze

**Agent OS for builders who ship.** Three models. One repo. Receipts.

> 🛠️ Need a second set of eyes on an AI agent or codebase architecture? I'm running 3 same-day [audit slots](https://buy.stripe.com/cNi8wR5Gj1GzbLt2wz1Fe02) this week — repo + 30-min call by EOD next day. See a sample finding in [this 2am postmortem](docs/POSTMORTEM_2AM_AGENT.md). Want the productized version? Try the [$49 spec bundle](https://buy.stripe.com/aFacN73yb0Cv6r9efh1Fe03) (GitHub PR bot + Code Review API + B2B audit playbook).


A Claude Code plugin that lets Claude watch and analyze video — local files **and** video URLs (YouTube, Vimeo, TikTok, X/Twitter, Instagram, Twitch, Reddit, direct `.mp4`, etc.).

No third-party AI dependency. Everything runs locally with `ffmpeg` + `whisper.cpp`. YouTube videos with real captions skip whisper entirely (10× faster).

## What it does

1. You hand Claude a video path or URL.
2. The plugin extracts sampled frames + a transcript to a temp directory.
3. Claude reads the frames (as images) and the transcript, then answers your question.

Works for:

- Local files: `.mp4`, `.mov`, `.webm`, `.mkv`, `.avi`, `.m4v`, `.flv`
- URLs: any site `yt-dlp` supports (~1000 of them)
- Live streams (capped at 5 min by default)

## Install

```bash
# 1. Install runtime deps (one-time)
#    macOS:
brew install ffmpeg yt-dlp whisper-cpp
#    Linux (Debian/Ubuntu):
sudo apt-get install ffmpeg yt-dlp     # whisper.cpp: build from source
#    Windows:
winget install Gyan.FFmpeg yt-dlp.yt-dlp

# 2. Install the plugin
#    Option A — Claude Code marketplace (recommended):
/plugin marketplace add github.com/sryharsha781-ctrl/claude-video-analyze
/plugin install video-analyze

#    Option B — manual:
git clone https://github.com/sryharsha781-ctrl/claude-video-analyze \
  ~/.claude/plugins/video-analyze
```

First whisper run downloads a ~150 MB English model into `~/.cache/whisper-cpp/`.

## Use

Just hand Claude a video:

```
> here's a clip /Users/me/Desktop/demo.mp4 — what's happening?
> what does this tutorial show?  https://youtu.be/xxxxxxxxxxx
> /video https://twitter.com/.../status/...  what's the code in the screen?
```

Or invoke the slash command directly:

```
/video <path-or-url> [your question]
```

## Options (pass to `analyze.sh`)

| Flag | Default | What it does |
|---|---|---|
| `--max-duration N` | `3600` (1 h) | Refuse videos longer than `N` seconds unless `--force` |
| `--fps RATE` | adaptive | Frame sample rate (e.g. `1/5` = one every 5 s) |
| `--hq` | off | Use 720 p instead of 360 p — slower, sharper text |
| `--force` | off | Override cache and duration cap |
| `--out DIR` | temp | Write artifacts to a specific directory |

## How it picks frames

Adaptive defaults based on video length:

| Duration | Frame interval |
|---|---|
| ≤ 30 s | 1 every 2 s |
| ≤ 2 min | 1 every 5 s |
| ≤ 10 min | 1 every 15 s |
| longer | 1 every 30 s |

## Privacy

All processing is local. Nothing is uploaded. Artifacts cached at:

```
$TMPDIR/claude-video-analyze/<sha1-hash>/
```

Clean up with `rm -rf "$TMPDIR/claude-video-analyze"`.

## Limitations

- Snapshot sampling, not true video understanding — fast-action content (sports, gameplay) loses temporal nuance. Tutorials, screen recordings, talking-heads, and demos work great.
- Private / login-required content needs `yt-dlp` cookies setup (not handled by default).
- Transcript quality on whisper depends on audio clarity; very noisy audio degrades.

## Check your install

```bash
bash ~/.claude/plugins/video-analyze/scripts/check-deps.sh
```

## License

MIT
