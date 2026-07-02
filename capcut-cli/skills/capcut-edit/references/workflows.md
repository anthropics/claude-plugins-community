# Workflows

Recipes for common edits. Every recipe is **"run this script"** — never a
multi-step sequence of `capcut` calls. If a recipe here grows beyond one
command, promote it to a new `scripts/*.sh`.

---

## Attach any intro / outro animation to a video/image segment

```
scripts/anim.sh <project> <segment-id> <slug> [<duration>]
```

`<slug>` is one of the keys in `assets/animations.json`:

| Slug | Type | Default | Feel |
|---|---|---|---|
| `fade-in` | in | 0.50s | gentle reveal from black |
| `flash-in` | in | 0.43s | bright bloom — punchy, for reveal beats |
| `pulsing-zooms` | in | 3.00s | breathing zoom — establishing shots |
| `scroll-up` | in | 1.20s | translate up — location reveals |
| `stripe-merge` | in | 0.63s | segmented wipe — transitional energy |
| `zoom-out` | in | 2.00s | slow zoom-out — contextual pull-back |
| `fade-out` | out | 0.50s | fade to black |
| `blur-out` | out | 1.00s | dreamy exit |
| `smoke` | out | 0.90s | vapor dissolve |

Intros are anchored at segment start (`start: 0`). Outros are auto-anchored
at segment end (`start: target_duration - duration`), matching how CapCut's
own outros are placed. Omit `<duration>` to use the slug's catalogue default.

**Why a script, not `capcut keyframe alpha`:** alpha keyframes in
`common_keyframes` are ignored by CapCut macOS on both video and text
segments. The only approach that renders is an entry in
`materials.material_animations` attached via the segment's
`extra_material_refs`. The script writes that structure and appends the new
material id.

**Dedicated wrappers:** `scripts/fade-in.sh` and `scripts/fade-out.sh` call
`anim.sh` with the slug baked in — convenient for the most common cases:

```
scripts/fade-in.sh  <project> <segment-id> [<duration>]
scripts/fade-out.sh <project> <segment-id> [<duration>]
```

**Guardrails in `anim.sh`:**
- Refuses to stack two animations of the same `type` on one segment; remove
  the existing one first.
- Refuses durations exceeding the segment's `target_timerange.duration`.
- Logs `cache_file_exists` in the JSON result — `false` means CapCut will
  fetch the effect from its online catalogue the first time it opens the
  project (normal for effects you haven't used locally yet).

**Picking a segment:** see `pitfalls.md` — inspect neighbour segments'
in/out animations, transitions on either side, and overlay tracks before
treating a segment as a clean visual test target.

---

---

## Ken Burns (scale + pan over a still image)

```
scripts/ken-burns.sh <project> <segment-id> \
  <start-scale> <end-scale> \
  <tx-start> <tx-end> \
  <ty-start> <ty-end> \
  <duration>
```

Writes 6 keyframes (uniform_scale × 2, position_x × 2, position_y × 2) via
`capcut keyframe --batch`. Motion properties render correctly in CapCut —
only `alpha` is broken (see `pitfalls.md`). Positions in half-canvas units:
`-1` = fully left/up, `1` = fully right/down, `0` = centre. Start with
`±0.05`–`±0.15` for subtle movement.

Typical presets:
- Slow zoom-in:   `1.0 1.2 0 0 0 0 3s`
- Zoom + pan left: `1.0 1.15 0 -0.1 0 0 3s`
- Pull-back:      `1.2 1.0 0 0 0 0 3s`

---

## Cut a range and stamp title + CTA

```
scripts/long-to-short.sh <project> <start> <end> <out-path> <title-text> <cta-text>
```

Three calls under the hood: `capcut cut` to extract the range, then two
`capcut add-text` calls — title at top for the first 3s, CTA at bottom for
the last 3s. Source project is not modified; output lands at `<out-path>`.

---

## Stamp a saved CTA template

```
scripts/stamp-cta.sh <project> <template.json> <start> <duration> [<text>]
```

Wraps `capcut apply-template` with an optional text override. A reusable
"Subscribe for more" template lives at
`assets/examples/subscribe-cta.json`; save your own with
`capcut save-template` and call `stamp-cta.sh` with that path.

---

## Discover segments, materials, timing

Not a recipe — one call, no branching. Use `capcut` directly:

```
capcut info     <project> -H
capcut tracks   <project> -H
capcut segments <project> --track video -H
capcut segment  <project> <id>
```

Only graduate to a `scripts/*.sh` when you're calling more than one command
or doing arithmetic over the output.
