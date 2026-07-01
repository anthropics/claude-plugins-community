# CV audit and maintenance

## Audit workflow

Use the full workflow only for broad CV audits, parser-safety reviews, or role-tailoring passes. For a single bullet, summary, section, or formatting question, inspect only the supplied material needed for that edit.

When the user supplies multiple document forms, choose the cheapest reliable source first:

- editable source such as LaTeX, Markdown, or DOCX text for content and rewrite recommendations
- rendered PDF for visual/render checks and plain-text extraction sanity checks
- large context files only for targeted verification of claims already visible in the CV

Do not turn a normal audit into full context reconciliation just because a comprehensive context file is available.

1. confirm the target role and seniority
2. check structural safety first
3. review section order and header naming
4. review summary, experience, skills, and education for relevance
5. compare against the user's source-of-truth materials for consistency
6. separate blocking issues from optional improvements

## ATS safety checklist

Check the following:

- single-column layout
- no tables, text boxes, sidebars, icons, or visual skill bars
- standard fonts and readable size
- contact info in the document body
- explicit URLs
- one consistent date format
- text-based export, not image-only PDF
- plain-text extraction reads in the correct order
- for generated LaTeX PDFs, post-build layout QA catches excessive whitespace, bad line wraps, one-word final lines, clipped text, and spacing inconsistencies

## Content checklist

- standard section names such as `Experience`, `Skills`, and `Education`
- summary aligned to the target role
- bullets show action, scope, tools, and outcomes
- important hard skills appear naturally in summary or experience
- top claims are supported by measurable evidence where possible
- no invented tools, employers, metrics, or certifications

## Consistency checklist

The CV should align with the user's context file, LinkedIn, and public work on:

- job titles
- employer names
- dates
- core technologies
- flagship projects
- certifications
- major outcomes

If facts conflict, stop and surface the conflict.

For bounded audits, report "no conflict found in inspected inputs" instead of implying complete verification across every source.

## Tailoring workflow

When a job description is available:

1. extract hard skills, tools, platforms, and domain terms
2. mirror the exact phrasing of the most important true terms
3. select the most relevant bullets and projects
4. rewrite summary and bullets for relevance without stuffing
5. keep speed in mind; do not over-polish past the application window

## Maintenance rules

- update only when a real role, project, certification, or result exists
- remove stale emphasis from the summary when target positioning changes
- reorder or prune skills when they are no longer central
- keep a source format that is easy to diff and update

## Output format for audits

When auditing a CV, organize findings into:

1. ATS or parser blockers
2. factual consistency issues
3. tailoring improvements
4. recruiter-readability improvements

For bounded audits, include one `Depth note` naming the document scope inspected, whether a job description/context file was used, and what a deeper pass would add.
