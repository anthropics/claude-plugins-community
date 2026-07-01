# CV parser risks and agent workflow

## Common parser risks

- critical info in headers or footers
- hyperlinks hidden behind anchor text only
- skill bars, stars, and visual ratings
- two-column layouts disguised with invisible tables
- inconsistent public facts between CV and LinkedIn
- image-only or scan-derived PDFs
- manual spacing hacks that break reading order

## Plain-text test

Use this cheap validation loop:

1. open the final PDF
2. copy all text
3. paste into a plain-text editor
4. confirm reading order, missing text, and character integrity

If the extracted text is scrambled, the layout is not ready.

## LaTeX PDF post-build QA

When the agent creates or edits a LaTeX CV and renders a PDF, run this compact check before calling it done:

1. confirm the PDF compiles without errors and review warnings that affect visible layout
2. run the plain-text test for reading order, missing text, ligature/character issues, and explicit URLs
3. visually inspect each page for wasted space, excessive blank lines, awkward section breaks, widows/orphans, one-word final lines, overfull text, clipped content, and inconsistent spacing
4. fix wording first when a small rewrite removes a bad line wrap; adjust layout only when content edits cannot solve the issue cleanly
5. keep ATS safety ahead of page filling; do not use fragile spacing hacks, hidden text, tiny fonts, or multi-column tricks to force density

Also check that generated LaTeX content avoids em dashes unless the user explicitly requested that style.

## Agent-friendly source workflow

- Prefer plain-text source when the user supports it.
- `.tex` is strong for versioned, programmatic editing.
- Keep content and layout macros separate.
- Agents should edit content blocks, not redesign the template unless asked.
- `.docx` can still be a valid final target, but it is less pleasant as the source of truth for repeated automated tailoring.

## Guardrails

- Never promise ATS success.
- Never claim a vendor-specific scoring rule unless sourced.
- Optimize for reliable parsing first, then recruiter readability, then visual polish.
