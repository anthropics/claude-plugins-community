# Pitfalls

Things that have burned people. Read before editing a real project.

---

## Close the project in CapCut before editing

CapCut holds the draft file open and rewrites it on window save / focus
change. If you edit `draft_info.json` while CapCut has the project loaded:

- Your write is silently overwritten on CapCut's next save.
- Or CapCut re-serialises with slightly different formatting, making diffs
  impossible to track.
- Worst case: CapCut detects the mtime jump, reloads, and loses any in-flight
  unsaved work on its side.

Always: close the project in CapCut → edit via `capcut-cli` → reopen in CapCut.

---

## `.bak` is always the *immediately* prior state, not a history

Every write creates `<draft>.bak` with the pre-write bytes. The previous
`.bak` is overwritten. `.bak` restores one step. If you need history, snapshot
manually with a timestamp suffix (`cp draft_info.json draft_info.json.pre<tag>`)
before the write.

**Do not** restore from a `.bak.<epoch>` file produced by another tool without
checking what state it holds — those are created by user workflows, not
capcut-cli, and may reflect a stale or incompatible schema (seen on
knossos-recon: `.bak.1776408172` pointed at a `knossos-act6-vXXXXX.mp3` file
that had been regenerated with a new hash and no longer existed on disk).

---

## Alpha keyframes don't render — use animation materials

`capcut keyframe <id> alpha …` writes to `common_keyframes`, but CapCut macOS
ignores alpha keyframes on both video and text segments. No fade renders.

For fade-in / fade-out, use `scripts/fade-in.sh` (and `fade-out.sh` when it
ships). They write a `materials.material_animations` entry — the mechanism
CapCut's own Blur Out / Fade In / Scroll animations use.

Alpha keyframes *are* harmless to leave in the file; they just do nothing. But
do not rely on them as a rendering primitive.

---

## `clip` is `null` on audio segments

Audio segments have no visual clip state: no opacity, no scale, no transform.
The JSON field is literally `"clip": null`. Do not `capcut opacity` an audio
segment — you'll get an error. `volume` is the audio analogue.

---

## `source_timerange` math when using `speed`

Setting `speed` doesn't change `target_timerange.duration` (on-timeline
duration). It changes `source_timerange.duration` (how much of the source
media is consumed):

```
source_timerange.duration = target_timerange.duration × speed
```

A 3-second target at speed 1.5 consumes 4.5 seconds of source. If the source
is shorter than `target × speed`, CapCut will play past the source end and
produce a black tail (video) or silence (audio). Check source length before
cranking speed.

---

## Neighbour segments bleed into your visual test

Before treating a segment as "clean" to verify a new intro/outro effect:

- Check the previous segment's `material_animations` for `type: "out"`. Its
  outro ends at your segment's start, visually mimicking an intro.
- Check the next segment's `material_animations` for `type: "in"`. Its intro
  begins at your segment's end, visually mimicking an outro.
- Check for transitions on either segment (not yet supported by capcut-cli,
  look in `materials.transitions` if present).
- Check overlay tracks (text, sticker, effect) whose timerange overlaps your
  test window — they mask the canvas.

Only when all four are clean is the target suitable for visually verifying a
new effect. When you can't make a segment neighbour-clean, inject the effect,
render a 2-second snippet, and compare to a reference frame.

---

## macOS vs Windows project files

- macOS filename: `draft_info.json`
- Windows filename: `draft_content.json`

capcut-cli auto-detects both. But if you `jq` or `grep` by name in scripts,
check both. Schema is otherwise identical.

The effect cache path in `material_animations.animations[].path` is absolute
and platform-specific:

- macOS: `/Users/<user>/Library/Containers/com.lemon.lvoverseas/Data/Movies/CapCut/User Data/Cache/effect/<effect_id>/<md5>`
- Windows: `C:\Users\<user>\AppData\Local\CapCut\User Data\Cache\effect\<effect_id>\<md5>`

Animation materials cloned from a macOS project into a Windows one need the
`path` rewritten; likely CapCut tolerates a missing path and re-fetches from
its catalogue, but this is unverified.

---

## JSON reserialisation normalises `1.0` → `1`

`JSON.stringify` in Node / Python's `json.dumps` both drop trailing `.0` from
floats. Semantically identical — CapCut parses either — but the file size
drops noticeably (~15 KB on a 2 MB draft: ~7800 floats × 2 chars). If you need
byte-exact round-trip, patch via string replace rather than
parse-then-serialize (seen on `knossos-recon` act6 fix).

---

## Don't trust a JSON write as proof the effect renders

Writing valid-looking JSON and seeing it persist on disk is necessary but
**not** sufficient. Before marking any effect work "done", open the project
in CapCut and visually confirm. Writing `common_keyframes` with
`property_type: "KFTypeAlpha"` produces valid JSON that looks correct in a
diff and does nothing at playback time. See
`feedback_verify_before_reporting.md`.
