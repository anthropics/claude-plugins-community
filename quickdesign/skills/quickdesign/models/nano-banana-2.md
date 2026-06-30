---
slug: nano-banana-2
category: image_edit
provider: fal | kie
status: primary
description: Nano Banana 2 (Gemini 2.5 Flash Image). Default for image-edit / multi-ref product composition / angle change / state change. Repeatable --reference-image accepts up to ~5 references; the model reasons over them in submission order as @Image1, @Image2, etc. Cheap (~12cr per 2K edit), fast, and the canonical pre-stage for any UGC video that needs a custom first-frame composition.
---

## When to use

- Avatar holding / wearing a product where you want pixel-faithful product detail (multi-ref: avatar + product side + product top)
- Angle change, state change (mouth empty when source had mouth full, glasses off, etc.)
- First-frame composition before feeding into Seedance R2V — banana ~12cr, Seedance ~250-500cr; a wrong first-frame chained into R2V wastes 50× the cost
- Product on white background, lifestyle composite, brand-kit-styled image

Skip in favor of `seedream-v4.5` if the user is on a tight budget AND the edit is simple identity-pin (no fine-print / brand-text fidelity needed). Banana handles brand text better but costs slightly more.

## Hard facts (live)

```bash
quickdesign cost nano-banana-2 -r 2K --num 1
quickdesign image models | jq '.data[] | select(.slug=="nano-banana-2")'
```

- Resolutions: `0.5K` (1.5×), `1K` (2×), `2K` (3× — default), `4K` (4×). Cost = `2 (base) × multiplier × num`.
- Default to `2K` for talking-head / selfie / lifestyle edits.
- Use `4K` only when the video integrates a **product** with fine detail (engraving, label text, stitching) where pixel fidelity matters in the downstream Seedance render.
- Aspect ratios: `1:1`, `9:16`, `16:9`, `4:5`. Match the downstream video aspect.

## Multi-reference grammar

Up to ~5 references is well-supported. Pass them as repeatable `--reference-image` in the order you want labeled:

```bash
quickdesign image generate \
  --model nano-banana-2 \
  --reference-image avatar.jpg \         # @Image1 — identity
  --reference-image product-side.jpg \   # @Image2 — product hero
  --reference-image product-top.jpg \    # @Image3 — product detail
  --aspect-ratio 9:16 --resolution 2K \
  -p "@Image1 holds a product matching @Image2 exactly. Replicate the stitching / lacing / sole color visible in @Image3. ..." \
  -o ./edit.png --wait
```

See `../references/multi-reference-pattern.md` for the full pattern, common mistakes, and pre-generation checklist.

## Compact prompt skeleton

```
Compose a single photo-realistic <aspect-ratio> frame using <N> reference images.
@Image1 is the subject — keep <face / hair / outfit identifying details> identical to the reference.
@Image2 (and @Image3 if supplied) is the product — render the held / worn item to match
@Image2 EXACTLY: <key textures / colors / stitching / brand text>. Do not invent details.
Scene: <setting>. Pose: <one-sentence action>. Lighting: <natural / studio / etc.>.
ANATOMY GUARD: exactly five fingers per hand, no extra digits, two normal feet,
hands and wrists clearly connected to forearms.
```

## Gotchas / failure modes

0. **Compose-mode regenerates the avatar instead of editing it.** When the prompt opens with "Compose a vertical 9:16 UGC selfie frame using two reference images..." or similar, banana renders a fresh AI-look image inspired by `@Image1` rather than modifying the source's pixels. The avatar's identity is approximated but the source's lighting, grain, and lo-fi authenticity are gone — output feels synthetic. **For UGC, default to edit-style prompts** (`Edit @Image1: add ...`, `Take @Image1 as-is and only change ...`). Don't re-list scene tokens already shown in the reference, and strip quality-upgrade phrases ("photo-realistic", "studio quality", "8K") — they trigger regen. See `../references/avatar-edit-not-regenerate.md` for the verb library + setting-lock principle.

1. **Hand / wrist hallucinations** when subject holds a partially-occluded prop. Failure modes: severed wrists, six-finger grips, floating hands, props phasing through fingers. Mitigation:
   - Switch to a TWO-HAND pose when single-hand grip keeps failing — banana handles two-hand grips far more reliably
   - Add explicit contact verbs ("palm wrapped around the heel, fingers gripping the toe")
   - Add an anatomy guard clause to the prompt: "exactly five fingers per hand, no extra digits, anatomically correct hands and wrists"
   - Silent regen ~12cr is cheap; the user's attention is not. Use 1-2 silent regens before paging the user. See `../references/confirmation-rules.md`.

2. **Fine print / engraving / label text drops or smears.** When the product has visible text (engraved "925" on jewelry, brand wordmarks, care labels, model numbers, billboard text in scene), banana routinely:
   - Drops the engraving entirely
   - Smears printed labels into illegible squiggles ("garbled text")
   - Replaces logos with similar-but-wrong glyphs

   Mitigation: **name the specific text in the prompt** (`"preserve the engraved 'OTTA 925' wordmark on the silver clasp exactly as in @Image2"`). Don't hand-wave with "preserve branding". The validator service checks for this; if the candidate drops fine print → retry with a sharper prompt.

3. **Identity drift on full-body shots.** Banana is strongest at tight selfie crops; full-body wide shots can drift on face details. Prefer half-body or selfie compositions when identity fidelity is critical.

4. **Verbose verbatim re-description fights the reference.** Same principle as Seedance: name the action / state / setting CHANGE, not the unchanged details. "Same person, same outfit, same setting — now without the crystal in mouth" works better than re-painting everything.

5. **`@Image1` syntax is shared with Seedance R2V** — but banana also accepts plain "the first image / second image" wording. Stick with `@Image1` for consistency across the pipeline.

## Cross-references

- Edit-style vs compose-style verbs (avatar authenticity) → `../references/avatar-edit-not-regenerate.md`
- Multi-product reference pattern → `../references/multi-reference-pattern.md`
- Anatomy self-check before paging user → `../references/confirmation-rules.md`
- Resolution decision (2K vs 4K) → `../pipelines/ugc-video.md` (resolution rule)
- Pre-stage for Seedance R2V → `./seedance-2.0-r2v.md`, `../pipelines/ugc-video.md`
