#!/usr/bin/env bash
# _test.sh — smoke-test every wrapper script against the canonical fixture.
#
# Each test copies `test/draft_content.json` to a fresh temp file, runs the
# script, and asserts a visible JSON-level effect. Prints one line per test.
# Exits non-zero if any test fails.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../.." && pwd)"
fixture="$repo_root/test/draft_content.json"
cli="$repo_root/dist/index.js"

if [[ ! -f "$fixture" ]]; then echo "missing fixture: $fixture" >&2; exit 1; fi
if [[ ! -f "$cli"     ]]; then echo "missing built CLI: $cli"   >&2; exit 1; fi

tmp="${TMPDIR:-/tmp}"
pass=0
fail=0

run() {
  local name="$1"; shift
  local draft="$tmp/capcut-edit-test-$RANDOM.json"
  cp "$fixture" "$draft"
  if "$@" "$draft" >/dev/null 2>&1; then
    printf '  ok    %s\n' "$name"
    pass=$((pass+1))
  else
    printf '  FAIL  %s\n' "$name"
    fail=$((fail+1))
  fi
  rm -f "$draft" "$draft.bak"
}

assert_json() {
  local name="$1"; shift
  local script="$1"; shift
  local assertion="$1"; shift
  local draft="$tmp/capcut-edit-test-$RANDOM.json"
  cp "$fixture" "$draft"
  if "$script" "$draft" "$@" >/dev/null 2>&1 \
     && node -e "const d=require('$draft'); process.exit(($assertion)?0:1)"; then
    printf '  ok    %s\n' "$name"
    pass=$((pass+1))
  else
    printf '  FAIL  %s\n' "$name"
    fail=$((fail+1))
  fi
  rm -f "$draft" "$draft.bak"
}

echo "capcut-edit scripts — smoke tests"

# fade-in.sh — intro animation on video segment aaaaaa01
assert_json "fade-in.sh (default 0.5s)" \
  "$script_dir/fade-in.sh" \
  "(d.materials.material_animations||[]).some(m => (m.animations||[]).some(a => a.name==='Fade In' && a.type==='in' && a.duration===500000))" \
  aaaaaa01

# fade-out.sh — outro animation on video segment aaaaaa02 (anchored at end)
assert_json "fade-out.sh 0.3s anchored at end" \
  "$script_dir/fade-out.sh" \
  "(d.materials.material_animations||[]).some(m => (m.animations||[]).some(a => a.name==='Fade Out' && a.type==='out' && a.duration===300000 && a.start === d.tracks[0].segments[1].target_timerange.duration - 300000))" \
  aaaaaa02 0.3s

# anim.sh — flash-in slug on aaaaaa01
assert_json "anim.sh flash-in" \
  "$script_dir/anim.sh" \
  "(d.materials.material_animations||[]).some(m => (m.animations||[]).some(a => a.name==='Flash In'))" \
  aaaaaa01 flash-in

# anim.sh — smoke outro slug on aaaaaa02
assert_json "anim.sh smoke (outro)" \
  "$script_dir/anim.sh" \
  "(d.materials.material_animations||[]).some(m => (m.animations||[]).some(a => a.name==='Smoke' && a.type==='out'))" \
  aaaaaa02 smoke

# ken-burns.sh — 6 keyframes (uniform_scale, position_x, position_y × 2)
assert_json "ken-burns.sh zoom-in pan" \
  "$script_dir/ken-burns.sh" \
  "(() => {
     const s = d.tracks[0].segments[0];
     const lists = s.common_keyframes || [];
     const props = ['UNIFORM_SCALE', 'KFTypePositionX', 'KFTypePositionY'];
     return props.every(p => {
       const L = lists.find(l => l.property_type === p);
       return L && L.keyframe_list.length === 2;
     });
   })()" \
  aaaaaa01 1.0 1.2 0 -0.1 0 -0.05 3s

# stamp-cta.sh — uses apply-template with the subscribe-cta.json fixture
assert_json "stamp-cta.sh (subscribe CTA, text override)" \
  "$script_dir/stamp-cta.sh" \
  "(d.materials.texts||[]).some(m => JSON.stringify(m).includes('Smash that like'))" \
  "$script_dir/../assets/examples/subscribe-cta.json" 0 2s "Smash that like"

# long-to-short.sh — writes to a new file; we inspect that file instead
name="long-to-short.sh (cut + title + CTA)"
src="$tmp/capcut-edit-test-long-$RANDOM.json"
dst="$tmp/capcut-edit-test-short-$RANDOM.json"
cp "$fixture" "$src"
if "$script_dir/long-to-short.sh" "$src" 1s 8s "$dst" "Highlight" "Subscribe" >/dev/null 2>&1 \
   && node -e "
     const d=require('$dst');
     const texts=(d.materials.texts||[]).map(t=>JSON.stringify(t));
     const hasTitle = texts.some(t=>t.includes('Highlight'));
     const hasCta   = texts.some(t=>t.includes('Subscribe'));
     process.exit((hasTitle && hasCta && d.duration === 7000000) ? 0 : 1);
   "; then
  printf '  ok    %s\n' "$name"
  pass=$((pass+1))
else
  printf '  FAIL  %s\n' "$name"
  fail=$((fail+1))
fi
rm -f "$src" "$src.bak" "$dst" "$dst.bak"

# Phase 1 decorators — direct CLI calls (no wrapper scripts)
cli_test() {
  local name="$1"; shift
  local assertion="$1"; shift
  local draft="$tmp/capcut-edit-test-$RANDOM.json"
  cp "$fixture" "$draft"
  if node "$cli" "$@" "$draft" "${@:2}" >/dev/null 2>&1; then :; fi  # no-op: use next form
  rm -f "$draft" "$draft.bak"
}

# transition on aaaaaa01
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
if node "$cli" transition "$draft" aaaaaa01 dissolve >/dev/null 2>&1 \
  && node -e "const d=require('$draft'); process.exit((d.materials.transitions||[]).some(t=>t.name==='Dissolve') ? 0 : 1)"; then
  printf '  ok    %s\n' "capcut transition dissolve"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut transition dissolve"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

# mask heart
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
if node "$cli" mask "$draft" aaaaaa01 heart --size 0.6 --feather 20 >/dev/null 2>&1 \
  && node -e "const d=require('$draft'); process.exit((d.materials.common_mask||[]).some(m=>m.name==='Heart' && m.config.height===0.6 && Math.abs(m.config.feather-0.2)<1e-9) ? 0 : 1)"; then
  printf '  ok    %s\n' "capcut mask heart"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut mask heart"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

# bg-blur level 2
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
if node "$cli" bg-blur "$draft" aaaaaa01 2 >/dev/null 2>&1 \
  && node -e "const d=require('$draft'); process.exit((d.materials.canvases||[]).some(c=>c.type==='canvas_blur' && c.blur===0.375) ? 0 : 1)"; then
  printf '  ok    %s\n' "capcut bg-blur 2"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut bg-blur 2"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

# text-style shadow+border
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
if node "$cli" text-style "$draft" cccccc01 --shadow --shadow-alpha 0.6 --border-width 0.08 --border-color "#FFFFFF" --border-alpha 1 >/dev/null 2>&1 \
  && node -e "const d=require('$draft'); const t=d.materials.texts[0]; process.exit(t.has_shadow===true && t.shadow_alpha===0.6 && t.border_width===0.08 ? 0 : 1)"; then
  printf '  ok    %s\n' "capcut text-style shadow+border"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut text-style shadow+border"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

# text-anim intro+outro
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
if node "$cli" text-anim "$draft" cccccc02 --intro typewriter --outro fade-out >/dev/null 2>&1 \
  && node -e "const d=require('$draft'); const a=(d.materials.material_animations||[]).find(m=>(m.animations||[]).some(x=>x.name==='Typewriter')); process.exit(a && a.animations.length===2 && a.animations.some(x=>x.type==='in') && a.animations.some(x=>x.type==='out') ? 0 : 1)"; then
  printf '  ok    %s\n' "capcut text-anim typewriter+fade-out"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut text-anim typewriter+fade-out"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

# Phase 2 — tracks
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
if node "$cli" add-sticker "$draft" sticker-xyz 1s 3s --x 0.3 --y -0.4 --scale 1.2 --rotation 15 >/dev/null 2>&1 \
  && node -e "const d=require('$draft'); const t=d.tracks.find(x=>x.type==='sticker'); const s=d.materials.stickers||[]; process.exit((t && t.segments.length===1 && s.length===1 && s[0].sticker_id==='sticker-xyz') ? 0 : 1)"; then
  printf '  ok    %s\n' "capcut add-sticker + track"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut add-sticker + track"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
if node "$cli" add-effect "$draft" vhs 0 5s --params '[80]' >/dev/null 2>&1 \
  && node -e "const d=require('$draft'); const t=d.tracks.find(x=>x.type==='effect'); const e=(d.materials.video_effects||[]).find(m=>m.name==='VHS'); process.exit((t && t.segments.length===1 && e && e.apply_target_type===2 && e.adjust_params.length===1) ? 0 : 1)"; then
  printf '  ok    %s\n' "capcut add-effect VHS + track"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut add-effect VHS + track"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
if node "$cli" image-anim "$draft" aaaaaa01 --intro fade-in --outro fade-out >/dev/null 2>&1 \
  && node -e "const d=require('$draft'); const mat=(d.materials.material_animations||[]).find(m=>(m.animations||[]).some(a=>a.name==='Fade In' && a.material_type==='video')); process.exit((mat && mat.animations.length===2 && mat.animations.some(a=>a.type==='in') && mat.animations.some(a=>a.type==='out')) ? 0 : 1)"; then
  printf '  ok    %s\n' "capcut image-anim video fade in+out"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut image-anim video fade in+out"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

# Phase 3 — enums + import-srt

# enums --transitions JSON: list is non-empty and includes "dissolve"
if node "$cli" enums --transitions 2>/dev/null \
   | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf-8')); process.exit(Array.isArray(d) && d.length>20 && d.some(e=>e.slug==='dissolve') ? 0 : 1)"; then
  printf '  ok    %s\n' "capcut enums --transitions"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut enums --transitions"; fail=$((fail+1))
fi

# enums --masks human table: must exit 0 and print a Split/Filmstrip row
if node "$cli" enums --masks -H 2>/dev/null | grep -q "^split "; then
  printf '  ok    %s\n' "capcut enums --masks -H"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut enums --masks -H"; fail=$((fail+1))
fi

# import-srt from stdin: 3 cues → 3 text segments on a "subtitle" track
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
srt=$'1\n00:00:00,000 --> 00:00:01,500\nFirst caption\n\n2\n00:00:01,500 --> 00:00:03,000\nSecond caption\n\n3\n00:00:03,000 --> 00:00:04,500\nThird caption\n'
if printf '%s' "$srt" | node "$cli" import-srt "$draft" - >/dev/null 2>&1 \
   && node -e "const d=require('$draft'); const t=d.tracks.find(x=>x.type==='text' && x.name==='subtitle'); process.exit((t && t.segments.length===3 && t.segments[0].target_timerange.start===0 && t.segments[1].target_timerange.start===1500000) ? 0 : 1)"; then
  printf '  ok    %s\n' "capcut import-srt (3 cues, stdin)"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut import-srt (3 cues, stdin)"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

# import-srt with --time-offset shifts all cues
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
if printf '%s' "$srt" | node "$cli" import-srt "$draft" - --time-offset 500ms >/dev/null 2>&1 \
   && node -e "const d=require('$draft'); const t=d.tracks.find(x=>x.type==='text' && x.name==='subtitle'); process.exit((t && t.segments[0].target_timerange.start===500000 && t.segments[2].target_timerange.start===3500000) ? 0 : 1)"; then
  printf '  ok    %s\n' "capcut import-srt --time-offset 500ms"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut import-srt --time-offset 500ms"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

# import-srt --style-ref mirrors font_size from an existing text segment.
# Pre-seed a big-font segment via text-style, then --style-ref it.
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
if node "$cli" text-style "$draft" cccccc01 --shadow --border-width 0.12 >/dev/null 2>&1 \
   && printf '%s' "$srt" | node "$cli" import-srt "$draft" - --track-name subs --style-ref cccccc01 >/dev/null 2>&1 \
   && node -e "const d=require('$draft'); const t=d.tracks.find(x=>x.type==='text' && x.name==='subs'); if(!t||t.segments.length!==3)process.exit(1); const mats=d.materials.texts||[]; const newMats=t.segments.map(s=>mats.find(m=>m.id===s.material_id)); process.exit(newMats.every(m=>m && m.has_shadow===true && m.border_width===0.12) ? 0 : 1)"; then
  printf '  ok    %s\n' "capcut import-srt --style-ref copies styling"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut import-srt --style-ref copies styling"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

# Phase 4 — text-ranges + --jianying

# text-ranges: 2 ranges on "Hello everyone" (14 chars) → 3 styles (gold "Hello", baseline " ", red "everyone")
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
if node "$cli" text-ranges "$draft" cccccc01 --styles '[{"start":0,"end":5,"font_color":"#FFD700","font_size":22,"bold":true},{"start":6,"end":14,"font_color":"#FF0000"}]' >/dev/null 2>&1 \
   && node -e "const d=require('$draft'); const c=JSON.parse(d.materials.texts[0].content); if(c.styles.length!==3)process.exit(1); const s0=c.styles[0], s2=c.styles[2]; const goldOk = s0.range[0]===0 && s0.range[1]===10 && s0.size===22 && s0.bold===true && Math.abs(s0.fill.content.solid.color[0]-1)<1e-6; const redOk = s2.range[0]===12 && s2.range[1]===28 && s2.fill.content.solid.color[0]===1 && s2.fill.content.solid.color[1]===0; process.exit((goldOk && redOk)?0:1)"; then
  printf '  ok    %s\n' "capcut text-ranges (2 ranges -> 3 styles)"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut text-ranges (2 ranges -> 3 styles)"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

# text-ranges: overlap error is caught
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
if ! node "$cli" text-ranges "$draft" cccccc01 --styles '[{"start":0,"end":5},{"start":3,"end":8}]' >/dev/null 2>&1; then
  printf '  ok    %s\n' "capcut text-ranges rejects overlap"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut text-ranges rejects overlap"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

# --jianying transition: JianYing identifiers are Chinese, so look up by Python
# member name (`_3D空间` is the first entry).
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
jy_member="$(node -e "console.log(require('$repo_root/dist/enums.json').jianying.transitions[0].member)")"
if node "$cli" transition "$draft" aaaaaa01 "$jy_member" --jianying >/dev/null 2>&1 \
   && node -e "const d=require('$draft'); process.exit(((d.materials.transitions||[]).length===1 && d.materials.transitions[0].name==='3D空间') ? 0 : 1)"; then
  printf '  ok    %s\n' "capcut transition --jianying (by member name)"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut transition --jianying (by member name)"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

# --jianying rejects a capcut-only slug (rgb-glitch is CapCut-only)
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
if ! node "$cli" transition "$draft" aaaaaa01 rgb-glitch --jianying >/dev/null 2>&1; then
  printf '  ok    %s\n' "capcut transition --jianying rejects capcut-only slug"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut transition --jianying rejects capcut-only slug"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

# --jianying mask by Chinese member
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
if node "$cli" mask "$draft" aaaaaa01 "线性" --jianying >/dev/null 2>&1 \
   && node -e "const d=require('$draft'); process.exit(((d.materials.common_mask||[]).length===1 && d.materials.common_mask[0].name==='线性') ? 0 : 1)"; then
  printf '  ok    %s\n' "capcut mask --jianying (by member)"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut mask --jianying (by member)"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

# --jianying text-anim by Chinese member
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
jy_text_intro="$(node -e "console.log(require('$repo_root/dist/enums.json').jianying.text_intros[0].member)")"
if node "$cli" text-anim "$draft" cccccc02 --intro "$jy_text_intro" --jianying >/dev/null 2>&1 \
   && node -e "const d=require('$draft'); const mat=(d.materials.material_animations||[]).find(m=>(m.animations||[]).some(a=>a.material_type==='text')); process.exit((mat && mat.animations.length===1 && mat.animations[0].type==='in') ? 0 : 1)"; then
  printf '  ok    %s\n' "capcut text-anim --jianying (by member)"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut text-anim --jianying (by member)"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

# --jianying image-anim by Chinese member
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
jy_img_intro="$(node -e "console.log(require('$repo_root/dist/enums.json').jianying.image_intros[0].member)")"
if node "$cli" image-anim "$draft" aaaaaa01 --intro "$jy_img_intro" --jianying >/dev/null 2>&1 \
   && node -e "const d=require('$draft'); const mat=(d.materials.material_animations||[]).find(m=>(m.animations||[]).some(a=>a.material_type==='video')); process.exit((mat && mat.animations.length===1 && mat.animations[0].type==='in') ? 0 : 1)"; then
  printf '  ok    %s\n' "capcut image-anim --jianying (by member)"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut image-anim --jianying (by member)"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

# --jianying add-effect (bypasses inline knossos catalogue)
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
if node "$cli" add-effect "$draft" 1998 0s 3s --jianying >/dev/null 2>&1 \
   && node -e "const d=require('$draft'); const e=(d.materials.video_effects||[]).find(m=>m.name==='1998'); process.exit((e && e.effect_id && e.resource_id) ? 0 : 1)"; then
  printf '  ok    %s\n' "capcut add-effect --jianying (ascii jianying slug)"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut add-effect --jianying (ascii jianying slug)"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

# --jianying add-effect: same slug 'shake' should NOT resolve to the CapCut inline effect_id
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
cc_shake_effect_id="$(node -e "const v = Object.entries(require('$repo_root/dist/enums.json').capcut.scene_effects||[]).find(([,e])=>e.slug==='shake'); console.log(v?v[1].effect_id:'')" 2>/dev/null || echo "")"
# In capcut namespace we have an inline shake with effect_id 7061205058364788270.
node "$cli" add-effect "$draft" shake 0s 3s >/dev/null 2>&1
cc_written="$(node -e "console.log((require('$draft').materials.video_effects[0]||{}).effect_id)")"
rm -f "$draft" "$draft.bak"
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
# With --jianying, inline bypass is active; 'shake' has no slug in jianying scene_effects → should error.
if ! node "$cli" add-effect "$draft" shake 0s 3s --jianying >/dev/null 2>&1; then
  printf '  ok    %s\n' "capcut add-effect --jianying bypasses inline catalogue (shake unmapped)"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "capcut add-effect --jianying bypasses inline catalogue (shake unmapped)"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"
echo "  note  CapCut inline 'shake' effect_id=$cc_written (expected 7061205058364788270)"

# Phase 5 — Wikimedia (offline smokes only; live coverage is in tmp scripts)

# Non-Wikimedia HTTPS URL is refused before any network call
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
if ! node "$cli" add-video "$draft" 'https://example.com/foo.jpg' 0s 3s >/dev/null 2>&1; then
  printf '  ok    %s\n' "add-video refuses non-Wikimedia URL"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "add-video refuses non-Wikimedia URL"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak"

# Local file path (non-URL) still works — regression check for the async refactor
draft="$tmp/capcut-edit-test-$RANDOM.json"; cp "$fixture" "$draft"
# Write a tiny fake jpg-named file — addVideo type-detects by extension only
fake_img="$tmp/fake-$RANDOM.jpg"; printf 'not really a jpg' > "$fake_img"
if node "$cli" add-video "$draft" "$fake_img" 0s 3s >/dev/null 2>&1 \
   && node -e "const d=require('$draft'); const v=d.tracks.find(x=>x.type==='video' && x.name==='video'); const seg=v && v.segments[0]; const mat=seg && d.materials.videos.find(m=>m.id===seg.material_id); process.exit(mat && mat.type==='photo' ? 0 : 1)"; then
  printf '  ok    %s\n' "add-video local path still works (async refactor)"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "add-video local path still works (async refactor)"; fail=$((fail+1))
fi
rm -f "$draft" "$draft.bak" "$fake_img"

# License classifier (unit-level, no network)
if node -e "
import('$repo_root/dist/wikimedia.js').then(({classifyLicense})=>{
  const cases = [['CC BY 4.0','permissive'],['CC0','permissive'],['Public domain','permissive'],['CC BY-NC 4.0','restrictive'],['Fair use','fair-use'],[null,'unknown']];
  for (const [v,w] of cases) if (classifyLicense(v)!==w) { console.error('fail',v); process.exit(1); }
  process.exit(0);
});
" 2>/dev/null; then
  printf '  ok    %s\n' "wikimedia license classifier (6 cases)"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "wikimedia license classifier (6 cases)"; fail=$((fail+1))
fi

echo ""
echo "results: $pass passed, $fail failed"
if (( fail > 0 )); then exit 1; fi
