<!--
metadata:
  wiki: agentkit-seo
  module: agentkit-seo-cv-ats
  title: "CV ATS runtime knowledge"
  status: stable
  confidence: likely
  last_reviewed: 2026-05-27
  review_by: 2026-08-27
  source_status: mixed
  agent_priority: high
-->

# CV ATS runtime knowledge

> This file contains durable CV and ATS knowledge for agents. Use it to keep resume structure, parser safety, tailoring, and factual grounding conservative and source-aware.

## 1. Load contract

Read this file only after [index.md](index.md) indicates that the current task needs compiled CV ATS knowledge.

If this file is unavailable in an older install, continue with `references/structure-and-formatting.md`, `references/parser-risks-and-agent-workflow.md`, `references/keywords-and-bullets.md`, `references/cv-audit-and-maintenance.md`, or `references/section-recipes.md` as appropriate. Mark parser, file-format, and confidence-label guidance as lower confidence if the wiki is unavailable.

## 2. Evidence labels

Use the AgentKit SEO evidence labels defined in `agentkit-seo/wiki/agentkit-seo.md`.

For CV work, `Verified` means the fact was observed in the CV, editable source, rendered PDF, plain-text extraction, supplied job description, supplied context file, or inspected public proof. `Inaccessible` commonly applies to ATS vendor scoring, recruiter screen behavior, hidden job filters, private profiles, and uninspected cross-platform facts.

## 3. Canonical definitions

**ATS-safe CV** means a resume or CV that uses simple, text-based structure so parsers and recruiters can recover contact details, sections, chronology, skills, and experience in a sensible order.

**Parser safety** means preserving text extraction, reading order, explicit URLs, standard section names, and basic character integrity across the final submission format.

**Tailoring** means selecting and rewriting true experience so it matches a target role or job description without fabricating skills, metrics, employers, dates, credentials, or outcomes.

**Plain-text extraction check** means copying or extracting the final document text and checking reading order, missing text, explicit URLs, and character issues before calling the CV submission-ready.

**Job-description alignment** means mapping real candidate evidence to the hard skills, tools, platforms, domain terms, and role expectations in a target job description.

## 4. Platform and parser constraints

- `stable`: Use a single-column layout for ATS-safe resumes.
- `stable`: Avoid tables, text boxes, sidebars, icons, graphics, skill bars, and hidden text when parser reliability matters.
- `stable`: Put contact details in the document body, not only in headers or footers.
- `stable`: Write URLs explicitly instead of relying only on hidden hyperlink anchors.
- `stable`: Use standard section names such as `Experience`, `Skills`, and `Education`.
- `stable`: Keep Experience and Education in reverse chronological order unless the user's background requires a different documented structure.
- `stable`: Never submit an image-only PDF when parsing matters.
- `stable`: Run a plain-text extraction sanity check before treating a final CV as submission-ready.
- `likely`: `.docx` and text-based PDF are safer final formats than image-heavy or layout-fragile exports, unless the employer requires another format.
- `likely`: 11pt body text is a safe default; 10pt is a practical lower bound in the current project methodology.
- `inferred`: Rewriting a bullet to remove a one-word final line is usually better than adding fragile spacing hacks.
- `disputed`: Exact ATS vendor scores, hidden knockout rules, or guaranteed parsing behavior should not be claimed without vendor-specific evidence.

## 5. Tailoring and keyword rules

- `stable`: Prioritize hard skills, tools, platforms, and domain terms from the job description when they truthfully match the candidate.
- `stable`: Put important keywords into context-rich bullets and summaries, not hidden text or repeated keyword dumps.
- `stable`: Use both long form and acronym on first mention when that improves parser or recruiter clarity.
- `likely`: Action + task or scope + tool or method + measurable result is the default bullet shape.
- `likely`: Approximate metrics are acceptable only when the source material gives enough basis and the wording makes the approximation clear.
- `inferred`: A shorter credible skills list is stronger than a bloated list of unsupported tools.

## 6. Agent failure modes

- Promising ATS success, exact scores, or guaranteed recruiter outcomes.
- Adding hidden keywords, fake metrics, invented tools, unverified credentials, or unsupported seniority.
- Optimizing visual density with fragile spacing hacks, tiny fonts, multi-column layouts, or hidden text.
- Treating a polished PDF as ready without a plain-text extraction check.
- Rewriting a CV from a job description so it reads like the job posting rather than the user's real experience.
- Claiming complete cross-platform consistency after inspecting only a bounded set of sources.
- Fetching or inferring LinkedIn, GitHub, or portfolio facts without user-supplied material or explicit lookup.
- Turning a narrow bullet edit into a full career-history rewrite.

## 7. Output rules

When producing a CV audit, tailoring pass, or parser-safety plan:

- State which CV source, rendered PDF, extraction output, job description, context file, or public proof was inspected.
- Separate ATS or parser blockers, factual consistency issues, tailoring improvements, and recruiter-readability improvements.
- Tie keyword recommendations to the supplied job description and the candidate's real evidence.
- Prefer exact revised bullets or section text over generic advice when the source material is sufficient.
- Use "no conflict found in inspected inputs" for bounded audits instead of implying full verification.
- Include a one-line `Depth note` for full-document audits, parser debugging, or intentionally bounded reviews.

Shared taxonomy: [agentkit-seo/wiki/agentkit-seo.md](../../agentkit-seo/wiki/agentkit-seo.md). Source grounding: [hub/cv-ats/sources.md](../../../../hub/cv-ats/sources.md).
