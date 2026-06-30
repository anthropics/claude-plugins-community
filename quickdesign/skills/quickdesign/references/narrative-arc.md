---
name: Multi-segment videos need a planned narrative arc — open / reveal / close
description: Don't write 3 isolated micro-action prompts. Plan a 3-beat storyline first (open → reveal → close), then write each segment's action line to advance the beat. The reference image carries identity/setting/style; the setting pin handles location continuity. Action descriptions implicitly cover prop state — if the action says "she bites the crystal", the crystal is present; if it says "mouth empty", it's gone. Plus: closer segments need action-loaded reference + motion-verb prompts, not still-life references.
---

Three connected layers handle multi-segment commercial coherence:

1. **Reference image** — locks identity, wardrobe, location aesthetic, lighting feel.
2. **`--reference-audio`** — locks voice character across segments (see `voice-continuity.md`).
3. **Narrative arc** — the planned 3-beat storyline that gives the cuts meaning.

The setting pin (`"in the same exact setting throughout — <specific scene tokens>"`) covers location continuity. The action description per segment naturally covers prop/accessory state — Seedance follows the prescribed action, so what's in the action lines is what ends up in the visual.

**Important nuance**: when the desired state in a segment **conflicts** with the reference image, **the reference image wins**. Action descriptions like "mouth is now empty — no crystal visible" cannot reliably override a reference image that shows the crystal in the mouth. Seedance treats the reference as a strong visual anchor, not just a style hint.

## Decision tree — when to generate a per-segment reference image

Before drafting prompts, walk through this decision per segment:

### 1. Is this a pure talking-head segment?

(Model talks/voiceovers, no major prop or pose change vs. previous segment)

→ **No new image. Reuse the source reference image.** Single reference works for the whole video. This covers the typical case (UGC promo where the model just speaks across segments). Cost: 0 image edits.

### 2. Does the segment require a state different from what the source reference shows?

For example: source has a crystal in mouth, this segment needs an empty mouth; or source has glasses on, this segment needs glasses off; or source has hands at sides, this segment needs hands holding a product up.

→ **Yes — if the state change is significant and the reference contradicts it, generate a state-matched reference via nano-banana-2 for THAT segment.** ~24cr per edit at 2K. Without this, the action description loses to the reference image and the state break is visible at the cut.

### 3. Borderline / ambiguous?

E.g. "she removes the sunglasses partway through" — reference shows glasses on, action shows them coming off mid-shot. Could go either way.

→ **Ask the user before burning credit.** Surface the question in the plan summary: "Seg 2 needs glasses-off at the close. Source has glasses on. Generate a glasses-off reference image (~24cr) or trust the action line and risk the reference winning?" Let them pick.

## Worst case — every segment a different state

A 3-segment video where each segment requires a distinct prop/pose state can need 3 separate nano-banana edits. Cost: ~72cr in image edits + 3 R2V calls. Surface this in the plan summary so the user can choose to simplify the arc if cost is a concern.

## Plan a 3-beat arc before writing prompts

Editorial commercials work because there is **a planned beat progression**:

- **Open** (Seg 1): subject is doing something specific that hooks attention. Posture / gaze / action that establishes the world.
- **Reveal** (Seg 2): the punchline beat. Visual changes meaningfully — a movement, a turn, a prop shift, a reveal of something new in frame. Segment 2 must EARN its existence with a beat change.
- **Close** (Seg 3): resolution / payoff. Brings the open back, lands the CTA, leaves the viewer with the brand mark.

Examples for an editorial perfume promo:

| Beat | Seg 1 (open) | Seg 2 (reveal) | Seg 3 (close) |
|---|---|---|---|
| A — gaze arc | Looks off-camera, brand-side | Slowly turns to lock eyes with lens | Holds gaze, slight smile |
| B — prop interaction | Crystal between teeth, stillness | Bites down → crystal cracks → chews fragments | Mouth empty, slow swallow, faint smile |
| C — product arc | No bottle, neutral pose | Bottle enters frame from below, near lips | Bottle held at chest, label readable |

Pick ONE arc and make sure every prompt's action line advances the chosen beat. Don't write three independent micro-actions — that gives Seedance no through-line and you get random gestures.

For voiceover (model not speaking) commercials, the arc is in **gaze / posture / prop**, not in mouth movement.

## Cardinal rule for the closer segment

**Don't use a "still life" reference image for the closer.** If the reference shows the subject already in their final pose (lying down, fully relaxed, hands at sides, mouth closed), Seedance has nowhere to go — it produces 11s of frozen output that looks dead.

The closer needs:
- **Action-loaded reference**: subject mid-gesture (pointing at something, mid-stride, head turning, hand reaching toward an object). Generate via nano-banana-2 if needed.
- **Motion-verb action lines**: "She lowers her hand from the wall, takes a small step back, and gives a soft shrug-smile" — concrete movement. Not "she quietly looks at the wall, camera holds steady" (that's a frozen recipe).

A closer that's literally "subject doing nothing in their final pose" produces dead output. Always design the closer with a small movement payoff.

## How to apply

1. **Storyline first.** Before drafting prompts, write a one-line beat per segment ("Seg 1: pointing at the panda. Seg 2: hand drops, turns to camera. Seg 3: smiles, slight wave."). Surface this in the plan summary so the user can okay or redirect the arc before generation burns credit.
2. Each segment's prompt has ONE prescriptive action line that names the beat — concrete enough that Seedance can render it (timestamps help: "around the third second she lowers her hand…").
3. Setting pin at the end: `"in the same exact setting throughout — <scene tokens>"`. Handles location continuity.
4. **Don't** add a state-lock block. The action line already constrains props by what it includes/excludes.
5. **For the closer**: never reuse a "final pose" reference. Always action-loaded + motion-verb lines.
