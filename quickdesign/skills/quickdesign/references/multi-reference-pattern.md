---
name: Multi-reference image pattern — pass every relevant photo as a separate reference, not as words
description: Both nano-banana-2 (image edit) and Seedance 2.0 R2V (video generate) accept multiple reference images via repeatable `--reference-image` flags. The model reasons over them in order as `@Image1`, `@Image2`, `@Image3`. Always pass photos that the agent has — describing them in prompt text as a substitute is a regression.
---

Both `quickdesign image generate --model nano-banana-2` and `quickdesign video generate --provider seedance` accept multiple reference images. The model reasons over them in submission order: first ref = `@Image1`, second = `@Image2`, etc. The prompt then refers to them by label, not by description.

**Hard rule:** if the user has uploaded multiple photos of the same subject (a product from front + top + detail, an actor in two outfits, a setting from two angles), pass ALL of them as references. Describing additional details in prose instead of passing them as references is a regression — the model has to imagine what the prose meant and almost always invents details that don't match what the user has.

## Why this matters

When the user gives you a product photo and you describe it in words ("beige sneaker with suede toe and ripstop body"), the model paints a *generic* sneaker that fits the description but is not the actual product. Stitching pattern, sole color, lace weave, brand-specific silhouette details — all interpolated. For UGC product ads this is a fail: the rendered shoe doesn't look like the user's shoe.

Pass the product image as `@Image2` and prompt: *"render the held shoe to match @Image2 exactly — replicate textures, stitching, sole color, lace pattern. Do not invent details."* The model copies pixels rather than imagining.

The same principle applies to multi-angle products: front + top + insole detail = `@Image2`, `@Image3`, `@Image4`. Each carries information the others don't.

## CLI invocation

### Image edit (nano-banana-2 — multi-ref banana edit)

```bash
quickdesign image generate \
  --model nano-banana-2 \
  --reference-image /path/to/avatar.jpg \      # @Image1 → identity
  --reference-image /path/to/product-side.jpg \ # @Image2 → product hero
  --reference-image /path/to/product-top.jpg \  # @Image3 → product detail
  --aspect-ratio 9:16 \
  --resolution 2K \
  --prompt "@Image1 holds a sneaker matching @Image2 exactly (replicate the stitching pattern visible in @Image3)..." \
  -o ./edit.png --wait
```

Up to ~5 references is well-supported. Beyond that the model starts dropping subtle ones; pick the most informative angles.

### Video generate (Seedance R2V — multi-ref to reduce in-motion drift)

For UGC product ads, pass BOTH the banana edit (subject + product compositioned) AND the raw product photos as references. The banana edit is `@Image1` — the action anchor. The raw product photos are `@Image2`, `@Image3` — pixel-anchors for the product so it doesn't drift / hallucinate during 12s of motion.

```bash
quickdesign video generate \
  --provider seedance \
  --reference-image /path/to/banana-edit.png \   # @Image1 → action / pose / setting
  --reference-image /path/to/product-side.jpg \  # @Image2 → product pixel anchor
  --reference-image /path/to/product-top.jpg \   # @Image3 → product detail anchor
  --duration 12 \
  --aspect-ratio 9:16 --resolution 1080p \
  --prompt "@Image1 — UGC selfie. The held shoe matches @Image2 / @Image3 exactly. The woman speaks: \"...\"" \
  -o ./seg.mp4 --wait
```

The product anchors don't dominate the action — Seedance treats them as identity locks for the prop. This is the same pattern as `audio_urls` for voice continuity, just for visual identity.

## When to skip multi-ref

- **Pure talking-head with no prop**: just the avatar selfie as `@Image1`. The action is "person talks at camera," no product or accessory in frame. Multi-ref adds noise.
- **Brand mood reference is generic**: don't pass random pretty photos as "style references" — the model treats every reference as something to anchor on, not as inspiration. Use prompt text for vibe, references for pixel-accurate identity.
- **You only have one good photo of the subject**: don't pass tiny / blurry / partial-body photos as filler. Quality over quantity.

## Common mistakes

1. **Passing the avatar twice as @Image1 and @Image2** thinking it strengthens identity. It doesn't — it just confuses the model. One identity reference is enough.
2. **Describing the product in prose AND passing it as @Image2.** Pick one — let the reference do the work, keep the prose for action and setting. Verbose prose dilutes the reference signal (same principle as `../models/seedance-2.0-r2v.md`).
3. **Forgetting to use the `@ImageN` label in the prompt.** Just attaching multiple images doesn't tell the model how to use them. Be explicit: `"@Image1 holds @Image2 / @Image3 in her right hand."`
4. **Single-image edit when the user gave multiple product photos.** This is the regression cited above. Always check what the user uploaded BEFORE drafting the prompt — if they sent 3 product angles, use 3 product angles.
5. **Compose-style verbs that trigger fresh-frame regeneration.** Even with multi-ref, if the prompt opens with "Compose a vertical 9:16 frame..." banana regenerates a fresh AI-look image instead of editing the avatar. For UGC use edit-style verbs (`Edit @Image1: add ...`); see `./avatar-edit-not-regenerate.md`.

## Checklist before generating

- [ ] What references did the user actually upload? (re-scan their messages)
- [ ] Subject identity → 1 reference
- [ ] Product / prop → as many angles as the user provided (typically 1-3)
- [ ] Are all references referenced by `@ImageN` label in the prompt?
- [ ] Is the prose describing things the references already show? (cut and let the references do the work)
- [ ] Is the prompt edit-style (`Edit @Image1: ...`) rather than compose-style (`Compose a frame...`)? Compose triggers regen and loses avatar authenticity.
