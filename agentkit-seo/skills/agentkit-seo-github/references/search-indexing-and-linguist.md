# GitHub search, indexing, and Linguist

## Code-search basics

- public code search depends on the default branch
- private repositories may be indexed for authorized users, but not for public recruiter discovery
- searchability is constrained by documented limits such as:
  - file size limits
  - searchable byte limits per file
  - repository file-count limits
  - archive status and query filters
  - fork-specific search restrictions

## Stable search rules

- keep the default branch non-empty
- keep showcase repositories mildly active over time
- use clear file names, symbol names, and directory names
- remember that archived repositories are read-only and can be filtered with `is:archived`, so active showcase repositories should usually stay unarchived
- understand that untouched forks are poor portfolio anchors because fork visibility in search is constrained

## Linguist rules

- GitHub language stats are based on Linguist and can be skewed by vendored, generated, or data-heavy files
- inspect the repository file mix before recommending `.gitattributes`
- use `.gitattributes` to mark generated, vendored, documentation, or data files correctly
- do not mark first-party source as vendored just to change the bar
- use Linguist overrides to correct representation, not to hide real source
- do not say language-stat fixes will guarantee recruiter discovery, Explore placement, or code-search ranking
- do not claim code-search tools will miss the repository solely because the language bar is imperfect

## Important caution

Some Linguist overrides affect search visibility. Recommend concrete `.gitattributes` only after inspecting file roles, and use the least aggressive correct attribute. Do not suggest broad vendored patterns for notebooks, docs, PDFs, or research artifacts from the profile page alone. If file roles are unclear, label the recommendation as `Needs inspection` and prefer About text, topics, and README framing.

## Agent output standard

When reviewing a repository for discoverability:

1. check public visibility and default-branch health
2. inspect metadata and README quality
3. inspect whether language stats misrepresent the real stack
4. suggest minimal `.gitattributes` fixes only where justified by inspected files
5. if file inspection is unavailable, label the Linguist recommendation as `Inference` and ask the user to verify the file roles before applying it
