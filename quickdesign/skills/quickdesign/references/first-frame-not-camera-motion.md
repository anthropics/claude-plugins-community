---
name: Multi-segment prompts describe first-frame composition, NOT camera motion
description: For multi-segment Seedance R2V videos, each segment's prompt should describe the starting framing/composition (wide / medium / close / over-shoulder), not a camera-motion arc (slow zoom-in, pull-back, static hold). Camera-motion language is unreliable across segments and adds prompt noise. Seedance produces natural micro-motion (breathing, head turns, gestures) by itself — let it.
---

In multi-segment UGC videos the cut between segments is the moment the viewer's eye lands somewhere new. **What matters is where each segment STARTS visually** — that becomes the new shot. Camera-motion direction within a 4-15 second segment is either ignored, randomized, or applied inconsistently from one Seedance call to the next.

## What to write in the prompt

**Do:** describe the starting framing as a still composition.
- "Medium shot framing chest-up"
- "Close-up framing of her face, framed upper-chest to top of head"
- "Over-the-shoulder, with the laptop screen visible in foreground"
- "Wide shot, full body in frame, environment dominant"
- "Vertical 9:16 selfie POV — face fills the upper two-thirds of the frame"

**Don't:** describe camera motion direction.
- ❌ "The camera slowly zooms in toward her face throughout the shot"
- ❌ "Slow push-in motion"
- ❌ "Static camera holding the position steady"
- ❌ "The camera pulls back gradually"

Seedance R2V already adds natural micro-motion (subject breathing, slight head turns, hand gestures, ambient parallax). Explicit camera motion either:
- Gets ignored (Seedance picks its own motion anyway)
- Gets randomized (3 segments come out with 3 visibly different motion personalities)
- Adds prompt noise that competes with the actual scene description and quoted speech

## Why this matters for multi-segment concat

When you cut Seg 1 → Seg 2 → Seg 3:
- Viewer's eye snaps to wherever Seg N+1's frame 1 lands
- If frame 1 is meaningfully different framing (medium → close-up), the cut reads as cinematography
- Within-segment motion (the 4-15s of micro-movement) is decoration — it doesn't define the cut

So prompt design becomes: **pick the starting frame per segment**, let Seedance handle the rest.

## When motion IS appropriate to mention

Subtle, action-driven motion descriptions tied to a specific beat are fine — they're action lines, not camera direction:

✅ "Around the third second she lowers her hand from the wall, takes a small step back" — character motion, not camera motion.

✅ "Her head turns toward the camera with a soft smile" — character motion.

❌ "The camera slowly orbits around her" — pure camera direction, unreliable.

The distinction: action lines describe what the subject does (Seedance respects these well); camera-motion lines describe how the lens moves (Seedance ignores or randomizes these).

## How to apply

**Default (documentary / casual UGC): all segments share the same framing.** Per SKILL.md cardinal rule #10, don't change camera angle / distance between segments unless the user explicitly asks. A street interview / kitchen demo / founder POV reads as one camera point — the cut is the gesture or line, not the angle. The "framing progression" example below is for the **explicit opt-in case** ("cinematic angle changes", "alternate angles each segment", "cut to close-up at the punchline"). Don't apply it silently.

```
─── Default (DO THIS by default) ────────────────────
Seg 1 first frame: "Medium shot framing chest-up, eye-level"
Seg 2 first frame: "Medium shot framing chest-up, eye-level"  (same as Seg 1)
Seg 3 first frame: "Medium shot framing chest-up, eye-level"  (same as Seg 1)

─── Cinematic progression (ONLY on explicit request) ─
Seg 1 first frame: "Wide medium shot framing chest-up, environment visible"
Seg 2 first frame: "Medium close-up framing shoulders to top of head"
Seg 3 first frame: "Close-up framing face only, eyes and mouth dominant"
```

Each segment then continues with: identity anchor (`@Image1`) + scene/setting (with the "in the same exact setting" pin if location continuity matters) + action line + quoted speech + lighting/format. **No camera-motion verbs** in either case.
