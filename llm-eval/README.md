# llm-eval

Evaluate LLM outputs against golden examples with tolerance-based scoring. A [Claude Code](https://claude.ai/claude-code) plugin that provides structured output comparison with configurable pass/fail thresholds — no external services or API keys required.

## Structure

```
llm-eval/
├── .claude-plugin/
│   ├── plugin.json        # Plugin metadata & userConfig
│   └── marketplace.json   # Marketplace listing
├── skills/
│   └── llm-eval/
│       ├── SKILL.md       # Skill instructions for Claude
│       ├── .version
│       └── references/
│           ├── comparators.md    # Detailed comparator documentation
│           └── config-schema.md  # Configuration schema reference
├── examples/
│   ├── text-qa-suite.json              # Text QA golden test suite
│   ├── numeric-extraction-suite.json   # Numeric extraction tests
│   ├── json-structure-suite.json       # JSON structure validation
│   └── regex-pattern-suite.json        # Regex pattern matching
├── LICENSE
└── README.md
```

## What it does

The llm-eval plugin teaches Claude how to evaluate LLM outputs against golden reference examples using seven comparator types and configurable scoring. It runs inline Python within your Claude Code session — nothing to install, no API calls.

### Comparators

| Comparator | Score type | Description |
|---|---|---|
| `exact` | binary (0/1) | Character-for-character match after normalization |
| `contains` | binary (0/1) | Expected string appears as substring of actual |
| `fuzzy` | continuous (0-1) | Levenshtein-based similarity ratio |
| `numeric` | binary (0/1) | Numeric comparison with absolute or relative tolerance |
| `regex` | binary (0/1) | Actual matches regex pattern defined in expected |
| `json_structure` | continuous (0-1) | JSON key/type/value comparison with partial scoring |
| `semantic` | continuous (0-1) | Bag-of-words cosine similarity |

### Scoring

Each test case gets a score from its comparator and passes if `score >= threshold`. Suite-level pass rate = passing cases / total cases. Optional gate thresholds let you enforce a minimum pass rate.

## Installation

Install via the Claude Code plugin system:

```bash
claude plugin marketplace add anthropics/claude-plugins-community
claude plugin install llm-eval@claude-community
```

Or for local development:

```bash
claude --plugin-dir ./llm-eval
```

## Usage

### Run an eval suite

Place your golden test suite in a JSON file and ask Claude to evaluate it:

```
Evaluate my test suite at ./my-eval-suite.json
```

### Inline evaluation

Describe your test cases directly:

```
I have these expected/actual pairs. Evaluate them with fuzzy matching at 0.8 threshold:
- Expected: "The capital of France is Paris" / Actual: "Paris is the capital of France"
- Expected: "42" / Actual: "The answer is 42"
```

### Compare prompt variants

```
Run both prompt-a-suite.json and prompt-b-suite.json and show me which test cases
improved or regressed between the two.
```

### Gate check

Add a `gate_threshold` to your suite JSON:

```json
{
  "suite_name": "release-gate",
  "gate_threshold": 0.95,
  "cases": [...]
}
```

The report will clearly state whether the gate passed or failed.

## Test suite format

```json
{
  "suite_name": "my-eval",
  "description": "What this suite tests",
  "default_comparator": "fuzzy",
  "default_threshold": 0.85,
  "gate_threshold": 0.90,
  "cases": [
    {
      "id": "case-001",
      "input": "What is the capital of France?",
      "expected": "Paris",
      "actual": "The capital of France is Paris.",
      "comparator": "contains",
      "threshold": 1.0,
      "tags": ["geography"],
      "config": { "case_insensitive": true }
    }
  ]
}
```

See `skills/llm-eval/references/config-schema.md` for the full schema and `skills/llm-eval/references/comparators.md` for detailed comparator documentation.

## Configuration

Plugin-level defaults can be set via userConfig:

| Setting | Default | Description |
|---------|---------|-------------|
| `LLM_EVAL_DEFAULT_THRESHOLD` | `1.0` | Global default pass threshold (0.0-1.0) |
| `LLM_EVAL_FUZZY_RATIO` | `80` | Default fuzzy match minimum similarity (0-100) |
| `LLM_EVAL_NUMERIC_TOLERANCE` | `0.01` | Default numeric tolerance (append `%` for relative) |

Configuration priority (highest wins): per-case > suite-level > plugin userConfig > hardcoded defaults.

## Example suites

The `examples/` directory contains four ready-to-use test suites demonstrating each comparator type:

- **text-qa-suite.json** — factual QA with exact, fuzzy, contains, and semantic comparators
- **numeric-extraction-suite.json** — numeric value extraction with absolute and relative tolerances
- **json-structure-suite.json** — JSON response validation with structure-only and value-checking modes
- **regex-pattern-suite.json** — format validation for emails, IPs, dates, UUIDs, phone numbers, and more

Run any example:

```
Evaluate the test suite at llm-eval/examples/text-qa-suite.json
```

## Report format

The evaluation produces a structured report:

```
## Eval Report: text-qa-basic

**Pass rate: 7/8 (87.5%)**

| ID     | Comparator | Score  | Threshold | Result |
|--------|-----------|--------|-----------|--------|
| qa-001 | contains  | 1.0000 | 1.00      | PASS   |
| qa-002 | contains  | 1.0000 | 1.00      | PASS   |
| qa-006 | contains  | 0.0000 | 1.00      | FAIL   |
| ...    | ...       | ...    | ...       | ...    |

### Failing cases

**qa-006** (contains, score: 0.00, threshold: 1.00)
- Expected: `Jupiter`
- Actual: `Saturn is the largest planet.`

### Gate: 75% minimum pass rate
Result: PASS (actual: 87.5%)
```

## License

MIT
