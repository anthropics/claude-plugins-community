#!/usr/bin/env bash
# anim.sh — attach a CapCut intro/outro animation to a video/image segment.
#
# Usage: anim.sh <project> <segment-id> <slug> [<duration>]
#
#   <project>    CapCut project directory OR draft JSON file.
#   <segment-id> 6+ char prefix of the segment UUID.
#   <slug>       Animation slug from ../assets/animations.json
#                  intros: fade-in, flash-in, pulsing-zooms, scroll-up,
#                          stripe-merge, zoom-out
#                  outros: fade-out, blur-out, smoke
#   <duration>   Optional time string (0.5s, 500ms, 1:00). Defaults to the
#                slug's catalogue default (see animations.json).
#
# Writes a `material_animations` entry matching the shape CapCut writes
# natively (seen on knossos-recon segments), then appends its id to the
# segment's `extra_material_refs`. Creates a `.bak` before writing.
#
# For intros the animation is placed at `start: 0` (segment-relative).
# For outros the animation is placed at `start: target_duration - duration`
# so it finishes exactly at the segment cut (matches the Blur Out pattern
# on `b11d518e` at 0:09 in knossos-recon).

set -euo pipefail

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "Usage: $0 <project> <segment-id> <slug> [<duration>]" >&2
  exit 2
fi

project="$1"
segment_id="$2"
slug="$3"
duration="${4:-}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
catalogue="$script_dir/../assets/animations.json"

if [[ ! -f "$catalogue" ]]; then
  echo "Animation catalogue not found at $catalogue" >&2
  exit 1
fi

exec node -e '
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const [, projectArg, segPrefix, slug, durOverride, cataloguePath] = process.argv;

const EFFECT_CACHE_BASE = path.join(
  process.env.HOME,
  "Library/Containers/com.lemon.lvoverseas/Data/Movies/CapCut/User Data/Cache/effect"
);

function parseTime(input) {
  const neg = input.startsWith("-");
  const clean = input.replace(/^[+-]/, "");
  if (clean.endsWith("ms")) return (neg ? -1 : 1) * Math.round(parseFloat(clean.slice(0, -2)) * 1000);
  if (clean.endsWith("s"))  return (neg ? -1 : 1) * Math.round(parseFloat(clean.slice(0, -1)) * 1e6);
  if (clean.includes(":")) {
    const parts = clean.split(":");
    const sec = parts.length === 3
      ? parseInt(parts[0]) * 3600 + parseInt(parts[1]) * 60 + parseFloat(parts[2])
      : parseInt(parts[0]) * 60 + parseFloat(parts[1]);
    return (neg ? -1 : 1) * Math.round(sec * 1e6);
  }
  const n = parseFloat(clean);
  if (isNaN(n)) throw new Error("invalid time: " + input);
  return (neg ? -1 : 1) * Math.round(n * 1e6);
}

function findDraft(p) {
  const stat = fs.statSync(p);
  if (stat.isFile()) return p;
  for (const name of ["draft_info.json", "draft_content.json"]) {
    const candidate = path.join(p, name);
    if (fs.existsSync(candidate)) return candidate;
  }
  throw new Error("no draft_info.json / draft_content.json under " + p);
}

function uuidUpper() {
  const b = crypto.randomBytes(16);
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  const h = b.toString("hex").toUpperCase();
  return h.slice(0,8)+"-"+h.slice(8,12)+"-"+h.slice(12,16)+"-"+h.slice(16,20)+"-"+h.slice(20);
}

const catalogue = JSON.parse(fs.readFileSync(cataloguePath, "utf8"));
const spec = catalogue[slug];
if (!spec) {
  console.error("Unknown animation slug: " + slug);
  console.error("Available: " + Object.keys(catalogue).join(", "));
  process.exit(1);
}

const durUs = durOverride ? parseTime(durOverride) : spec.default_duration_us;
if (durUs <= 0) { console.error("duration must be > 0"); process.exit(2); }

const file = findDraft(projectArg);
const raw = fs.readFileSync(file, "utf8");
fs.writeFileSync(file + ".bak", raw, "utf8");
const d = JSON.parse(raw);

let targetSeg = null;
for (const t of d.tracks || []) for (const s of t.segments || []) {
  if (s.id && s.id.startsWith(segPrefix)) targetSeg = s;
}
if (!targetSeg) { console.error("segment not found: " + segPrefix); process.exit(1); }

// Refuse to overwrite an existing animation of the same type.
const animsById = Object.fromEntries((d.materials.material_animations || []).map(a => [a.id, a]));
for (const ref of targetSeg.extra_material_refs || []) {
  const existing = animsById[ref];
  if (!existing) continue;
  for (const a of existing.animations || []) {
    if (a.type === spec.type) {
      console.error("segment already has a " + spec.type + " animation (" + a.name + "). Remove it first.");
      process.exit(1);
    }
  }
}

const targetDur = targetSeg.target_timerange.duration;
if (durUs > targetDur) {
  console.error("duration (" + durUs + "us) exceeds segment duration (" + targetDur + "us)");
  process.exit(1);
}

const start = spec.type === "out" ? (targetDur - durUs) : 0;
const cachePath = path.join(EFFECT_CACHE_BASE, spec.effect_id, spec.md5);
const newId = uuidUpper();

const animMat = {
  animations: [{
    anim_adjust_params: null,
    category_id: spec.category_id,
    category_name: spec.category_id,
    duration: durUs,
    id: spec.effect_id,
    material_type: spec.material_type,
    name: spec.name,
    panel: spec.material_type,
    path: cachePath,
    platform: "all",
    request_id: "",
    resource_id: spec.resource_id,
    source_platform: 1,
    start: start,
    third_resource_id: spec.third_resource_id,
    type: spec.type
  }],
  id: newId,
  multi_language_current: "none",
  type: "sticker_animation"
};

if (!Array.isArray(d.materials.material_animations)) d.materials.material_animations = [];
d.materials.material_animations.push(animMat);

targetSeg.extra_material_refs = targetSeg.extra_material_refs || [];
targetSeg.extra_material_refs.push(newId);

fs.writeFileSync(file, JSON.stringify(d), "utf8");

console.log(JSON.stringify({
  ok: true,
  segment_id: targetSeg.id,
  slug: slug,
  name: spec.name,
  type: spec.type,
  material_id: newId,
  start_us: start,
  duration_us: durUs,
  cache_file_exists: fs.existsSync(cachePath)
}));
' -- "$project" "$segment_id" "$slug" "$duration" "$catalogue"
