#!/usr/bin/env bash
# video-analyze: extract frames + transcript from a local video file or URL.
# Output is a directory containing frames/*.jpg, transcript.txt, metadata.json.
# Claude reads those artifacts and answers the user's question.
#
# Usage:
#   analyze.sh <path-or-url> [--max-duration SECONDS] [--fps RATE]
#              [--hq] [--force] [--out DIR]
#
# Exits 0 on success and prints the artifact directory path on the last line.

set -euo pipefail

INPUT=""
MAX_DURATION=3600          # 60 min default cap
FPS=""                     # auto-picked from duration if empty
RES="360"                  # max height; --hq bumps to 720
FORCE=0
OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-duration) MAX_DURATION="$2"; shift 2 ;;
    --fps)          FPS="$2"; shift 2 ;;
    --hq)           RES="720"; shift ;;
    --force)        FORCE=1; shift ;;
    --out)          OUT="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,11p' "$0"; exit 0 ;;
    *)
      if [[ -z "$INPUT" ]]; then INPUT="$1"; else
        echo "Unknown arg: $1" >&2; exit 2
      fi
      shift ;;
  esac
done

if [[ -z "$INPUT" ]]; then
  echo "Usage: $0 <path-or-url> [options]" >&2; exit 2
fi

# ---------- helpers ----------
err() { echo "[video-analyze] $*" >&2; }
need() {
  command -v "$1" >/dev/null 2>&1 || {
    err "missing dependency: $1"; exit 3
  }
}
need ffmpeg
need ffprobe

# Cache directory: hash of input → reuse if already analyzed
hash_input() {
  if [[ -f "$INPUT" ]]; then
    # file: hash path + mtime + size so re-encodes invalidate
    local mtime size
    mtime=$(stat -f %m "$INPUT" 2>/dev/null || stat -c %Y "$INPUT")
    size=$(stat -f %z "$INPUT"  2>/dev/null || stat -c %s "$INPUT")
    printf "%s|%s|%s" "$INPUT" "$mtime" "$size" | shasum | cut -d' ' -f1
  else
    printf "%s" "$INPUT" | shasum | cut -d' ' -f1
  fi
}

HASH=$(hash_input)
CACHE_ROOT="${TMPDIR:-/tmp}/claude-video-analyze"
mkdir -p "$CACHE_ROOT"
WORK="${OUT:-$CACHE_ROOT/$HASH}"

if [[ -f "$WORK/.done" && $FORCE -eq 0 ]]; then
  err "cache hit, reusing $WORK (pass --force to redo)"
  echo "$WORK"; exit 0
fi

mkdir -p "$WORK/frames"
META="$WORK/metadata.json"
TRANSCRIPT="$WORK/transcript.txt"
FRAMES_DIR="$WORK/frames"
VIDEO=""

# ---------- step 1: get a local file ----------
is_url=0
if [[ "$INPUT" =~ ^https?:// ]]; then is_url=1; fi

if [[ $is_url -eq 1 ]]; then
  need yt-dlp
  err "downloading via yt-dlp..."
  # cap resolution, cap duration, save lowest acceptable format
  VIDEO="$WORK/source.mp4"
  yt-dlp \
    --no-playlist \
    --format "best[height<=${RES}]/best" \
    --merge-output-format mp4 \
    -o "$VIDEO" \
    --no-warnings --quiet \
    "$INPUT" 2>"$WORK/yt-dlp.log" || {
      err "yt-dlp failed; see $WORK/yt-dlp.log"; exit 4
    }

  # also try to grab captions (real, then auto-generated)
  yt-dlp \
    --skip-download \
    --write-subs --write-auto-subs \
    --sub-langs "en.*" \
    --convert-subs srt \
    -o "$WORK/source.%(ext)s" \
    --no-warnings --quiet \
    "$INPUT" 2>>"$WORK/yt-dlp.log" || true
else
  if [[ ! -f "$INPUT" ]]; then
    err "not a file and not a URL: $INPUT"; exit 2
  fi
  VIDEO="$INPUT"
fi

# ---------- step 2: probe ----------
DURATION=$(ffprobe -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 "$VIDEO" | awk '{printf "%d", $1}')
WIDTH=$(ffprobe  -v error -select_streams v:0 -show_entries stream=width  -of csv=p=0 "$VIDEO" || echo "")
HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$VIDEO" || echo "")

if (( DURATION > MAX_DURATION )) && [[ $FORCE -eq 0 ]]; then
  err "video is ${DURATION}s > cap ${MAX_DURATION}s; pass --force or raise --max-duration"
  exit 5
fi

# ---------- step 3: adaptive frame sampling ----------
if [[ -z "$FPS" ]]; then
  if   (( DURATION <= 30  )); then FPS="1/2"      # 1 frame every 2s
  elif (( DURATION <= 120 )); then FPS="1/5"
  elif (( DURATION <= 600 )); then FPS="1/15"
  else                              FPS="1/30"
  fi
fi

err "extracting frames @ $FPS (duration ${DURATION}s)..."
ffmpeg -loglevel error -y -i "$VIDEO" \
  -vf "fps=${FPS},scale=-2:${RES}" \
  -q:v 4 \
  "$FRAMES_DIR/frame_%04d.jpg"

FRAME_COUNT=$(find "$FRAMES_DIR" -name 'frame_*.jpg' | wc -l | tr -d ' ')

# ---------- step 4: transcript ----------
# Path A: YouTube captions exist → use them, skip whisper
SRT_FILE=$(find "$WORK" -maxdepth 1 -name 'source*.srt' | head -1 || true)
USED_CAPTIONS=0
if [[ -n "$SRT_FILE" && -s "$SRT_FILE" ]]; then
  err "using fetched captions ($SRT_FILE)"
  # flatten SRT → plain text with [hh:mm:ss] timestamps
  awk '
    /^[0-9]+$/ { next }
    /-->/ { t=$1; gsub(/,.*/, "", t); next }
    /^$/ { next }
    { if (t!="") { printf "[%s] ", t; t="" } print }
  ' "$SRT_FILE" > "$TRANSCRIPT"
  USED_CAPTIONS=1
else
  # Path B: extract audio and run whisper.cpp
  err "extracting audio + transcribing..."
  WAV="$WORK/audio.wav"
  ffmpeg -loglevel error -y -i "$VIDEO" -ac 1 -ar 16000 -vn "$WAV"

  if command -v whisper-cli >/dev/null 2>&1; then
    WHISPER_BIN="whisper-cli"
  elif command -v whisper-cpp >/dev/null 2>&1; then
    WHISPER_BIN="whisper-cpp"
  elif command -v whisper >/dev/null 2>&1; then
    WHISPER_BIN="whisper"
  else
    err "no whisper binary found; transcript will be empty"
    WHISPER_BIN=""
  fi

  if [[ -n "$WHISPER_BIN" ]]; then
    # Locate a model. whisper.cpp ships nothing by default; cache one on first use.
    MODEL_DIR="$HOME/.cache/whisper-cpp"
    MODEL="$MODEL_DIR/ggml-base.en.bin"
    if [[ ! -f "$MODEL" ]]; then
      mkdir -p "$MODEL_DIR"
      err "downloading whisper base.en model (~150MB, one time)..."
      curl -fsSL -o "$MODEL" \
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin" \
        || { err "model download failed"; MODEL=""; }
    fi
    if [[ -n "$MODEL" && -f "$MODEL" ]]; then
      "$WHISPER_BIN" -m "$MODEL" -f "$WAV" -otxt -of "$WORK/audio" >/dev/null 2>&1 || true
      [[ -f "$WORK/audio.txt" ]] && mv "$WORK/audio.txt" "$TRANSCRIPT"
    fi
  fi
  [[ -f "$TRANSCRIPT" ]] || : > "$TRANSCRIPT"
fi

# ---------- step 5: metadata ----------
cat > "$META" <<JSON
{
  "input": "$INPUT",
  "is_url": $is_url,
  "duration_s": $DURATION,
  "width": "${WIDTH:-}",
  "height": "${HEIGHT:-}",
  "fps_sampled": "$FPS",
  "frame_count": $FRAME_COUNT,
  "transcript_source": "$([[ $USED_CAPTIONS -eq 1 ]] && echo captions || echo whisper)",
  "max_resolution": "$RES",
  "work_dir": "$WORK"
}
JSON

touch "$WORK/.done"
err "done: $FRAME_COUNT frames, transcript=$(wc -c <"$TRANSCRIPT" | tr -d ' ') chars"
echo "$WORK"
