---
name: Edit the avatar, don't regenerate it — preserve the source's authenticity
description: When the user supplies an avatar (selfie, lifestyle photo, portrait) and the setting doesn't change, prompt the image-edit model to MODIFY the source rather than COMPOSE a fresh frame. Compose-style prompts ("compose a single photo-realistic frame...", "generate a UGC creator selfie...") cause banana / Gemini Flash Image to render a new image inspired by the avatar — losing the source's lighting, grain, and lo-fi authenticity. Edit-style prompts ("edit @Image1 to add...", "preserve every pixel of @Image1 except [region]") nudge the model toward in-place modification.
---

When the user uploads a creator selfie / portrait / avatar reference for a UGC video, you have two ways to ask `nano-banana-2` to add a product / change the pose / modify a state:

| Prompt style | What banana does | Effect on output |
|---|---|---|
| **Compose-style** ("Compose a vertical 9:16 UGC selfie frame using two references...") | Renders a fresh image inspired by the references | New AI-look image. Source lighting, grain, lo-fi authenticity gone. Identity preserved but feels polished/synthetic. |
| **Edit-style** ("Edit @Image1: add a sneaker held in her right hand. Keep everything else identical.") | Modifies the source pixels, only changes the requested region | Source's lighting, grain, color cast, slight blur, "phone selfie" quality preserved. Output looks like the user edited their own photo. |

For UGC ads where the appeal is *real-creator authenticity*, **edit-style is the correct default**. Compose-style is the regression.

## When to use each

**Edit-style — DEFAULT for UGC:**
- Avatar reference is a real creator selfie / lifestyle photo
- Setting doesn't change between source and segment
- Only ONE local change is needed (held product, pose change, state change)
- User wants the output to look like a real social post, not an AI-generated render

**Compose-style — only when you NEED a new frame:**
- The setting must change ("she's now in a kitchen, not a bedroom")
- Multiple simultaneous changes (outfit + pose + setting + lighting)
- Source is so far from the target composition that editing isn't viable (e.g., source is a portrait, target is full-body)
- User explicitly asks for a "polished" / "studio" look

If you find yourself writing "compose-style" because the change feels too big to edit, ask whether you actually need a fresh frame or whether you could break the change into smaller edits across segments instead.

## Verb library

❌ **Compose-style triggers** (avoid for UGC unless setting changes):
- "Compose a vertical 9:16 frame..."
- "Generate a UGC creator selfie video frame..."
- "Create an image of..."
- "Render a scene where..."
- "Produce a photo-realistic..."
- "Build a composition..."
- "Photo-realistic Instagram/TikTok creator clip aesthetic" (this phrase ALONE causes regen — banana re-renders to match its idea of "TikTok aesthetic")

✅ **Edit-style triggers** (DEFAULT):
- "Edit @Image1 to add..."
- "Modify @Image1 by adding..."
- "Take @Image1 as-is and only change..."
- "Preserve every pixel of @Image1 except for..."
- "Keep @Image1 unchanged. Add..."
- "Same exact image as @Image1, but with..."

## Quality / grain preservation

Banana on regenerate has a tendency to "improve" the image — bumps perceived sharpness, adds professional studio lighting, smooths skin, removes phone-selfie tells. For UGC this kills the authenticity that makes the ad work.

**Don't add quality-upgrade words:**
- ❌ "Photo-realistic" / "high-resolution" / "8K" / "high definition" / "studio quality" / "professional photography"
- ❌ "Sharp focus" / "perfect lighting" / "magazine cover quality"

**Do anchor the source's vibe:**
- ✅ "Match the lighting, grain, and casual phone-selfie quality of @Image1 exactly"
- ✅ "Preserve the existing photographic quality and color cast of @Image1"
- ✅ "Lo-fi creator-selfie aesthetic — same as @Image1"

## Setting-lock principle

If the segment takes place in the same setting as the source avatar, **don't re-list scene tokens in the prompt**. Banana reads "cream walls, plant in corner, framed art on the wall, soft natural daylight" as a fresh scene description and re-paints them — even when the source already shows them. Drift accumulates.

✅ Right (setting locked to source):
```
Edit @Image1 to add a beige low-top sneaker matching @Image2 EXACTLY,
held with both hands at chest level. Keep the room, lighting, outfit,
hair, makeup, jewelry, and pose framing unchanged from @Image1.
```

❌ Wrong (re-painting the setting):
```
Compose a single photo-realistic vertical 9:16 UGC creator selfie video frame.
@Image1 is the woman — keep her face... Scene: a casual cozy bedroom or small
living room, soft natural daylight from a window to one side, neutral cream-
colored wall behind her with shallow depth of field, part of a houseplant or
framed art glimpsed at the edge of the frame...
```

The wrong version is the kind of prompt I (Claude) tend to write by default — verbose, scene-prescriptive, and inadvertently triggering compose-mode. Trust the reference. Describe only what's NEW.

## Multi-product UGC: still edit-style

Even with multi-ref (avatar + product side + product top), the verb stays edit-style:

```
Edit @Image1: add a beige low-top sneaker matching @Image2 / @Image3 exactly
in her right hand, held at chest level with the side profile facing the lens.
Keep her face, hair, outfit, jewelry, the room, and the lighting unchanged
from @Image1. Replicate the sneaker's stitching pattern, suede toe, and
gum sole pixel-faithfully from @Image2 and @Image3 — do not invent details.
```

The product references work the same way as before — they're still pixel anchors via `@Image2` / `@Image3`. The only change is the verb at the top of the prompt.

## When this rule conflicts with another

- **Significant state change** (mouth empty when source has crystal in it) → still use edit-style if possible: "Edit @Image1: change her mouth to closed and relaxed (no crystal)." Only escalate to compose-style if banana refuses to honor the edit.
- **Complete pose change** (sitting → standing) → edit-style usually still works ("Edit @Image1 to change her pose from sitting to standing in the same room"); fall back to compose-style only if the pose change is dramatic enough that pixel preservation isn't possible anyway.

## Why this matters for the downstream Seedance segment

The banana edit becomes Seg 1's `@Image1` for Seedance R2V. Seedance derives its first-frame from this image — so if the banana edit looks "AI-rendered polished" rather than "real creator selfie", the entire 12s video inherits that polished feel and the UGC authenticity is lost.

This is why the rule lives at the banana stage, not the Seedance stage: by the time Seedance runs, the aesthetic is already locked.

## How to apply

1. **Default**: every banana edit destined for UGC starts with `Edit @Image1: ...` not `Compose ...`. 
2. **Setting check**: if the segment's setting matches the avatar's setting, don't list scene tokens in the prompt. Trust the reference.
3. **Quality check**: re-read your prompt before submitting. If it contains "photo-realistic" / "high-resolution" / "professional" / "studio quality", strip those — they trigger regen.
4. **Verify on output**: when you Read the rendered banana edit, ask "does this look like the user's selfie with a tweak, or like a fresh AI render of someone who resembles the user?" The first is right. The second means the prompt was compose-style.
