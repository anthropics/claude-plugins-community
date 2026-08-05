# Configuration schema

Configuration flows through three layers, from lowest to highest priority:

1. **Hardcoded defaults** — built into the evaluation script
2. **Plugin-level user config** — set via `userConfig` in `plugin.json` (environment variables)
3. **Suite-level defaults** — `default_comparator` and `default_threshold` in the suite JSON
4. **Per-case overrides** — `comparator`, `threshold`, and `config` on individual test cases

Higher-priority settings override lower ones.

## Plugin-level configuration

Set these through the Claude Code plugin settings UI or as environment variables:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `LLM_EVAL_DEFAULT_THRESHOLD` | float (0.0-1.0) | `1.0` | Global default pass threshold |
| `LLM_EVAL_FUZZY_RATIO` | int (0-100) | `80` | Default minimum fuzzy similarity (divided by 100 to get threshold) |
| `LLM_EVAL_NUMERIC_TOLERANCE` | string | `"0.01"` | Default numeric tolerance. Append `%` for relative (e.g., `"5%"`) |

## Suite-level configuration

Top-level fields in the test suite JSON:

```json
{
  "suite_name": "my-suite",
  "description": "Optional description",
  "default_comparator": "fuzzy",
  "default_threshold": 0.85,
  "gate_threshold": 0.90,
  "cases": [...]
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `suite_name` | string | `"unnamed"` | Unique suite identifier, used in reports |
| `description` | string | `""` | Human-readable description |
| `default_comparator` | string | `"exact"` | Comparator applied to cases that don't specify one |
| `default_threshold` | float | `1.0` | Pass threshold for cases that don't specify one |
| `gate_threshold` | float | none | If set, the report includes a gate check: pass rate must meet this value |
| `cases` | array | required | Array of test case objects |

## Per-case configuration

Each test case in the `cases` array:

```json
{
  "id": "case-001",
  "input": "What is 2 + 2?",
  "expected": "4",
  "actual": "The answer is 4",
  "comparator": "contains",
  "threshold": 1.0,
  "tags": ["arithmetic"],
  "config": {}
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Unique case identifier |
| `input` | string | no | The prompt that produced the actual output |
| `expected` | string/object | yes | Golden reference (string for most comparators, object for `json_structure`) |
| `actual` | string/object | yes | LLM output to evaluate |
| `comparator` | string | no | Overrides suite default |
| `threshold` | float | no | Overrides suite default |
| `tags` | string[] | no | For grouping in reports |
| `config` | object | no | Comparator-specific options (see `comparators.md`) |

## Comparator-specific config

Each comparator accepts its own config options via the `config` field on a test case. These are documented in `references/comparators.md`. Summary:

### Normalization (shared by exact, contains, fuzzy, semantic)

```json
{
  "case_insensitive": true,
  "strip_whitespace": true,
  "strip_punctuation": false
}
```

### Numeric

```json
{
  "tolerance": 0.01,
  "tolerance_type": "absolute"
}
```

`tolerance_type` can be `"absolute"` (default) or `"relative"`. Relative tolerance is computed as a fraction of the expected value.

### Regex

```json
{
  "case_insensitive": true,
  "dotall": false,
  "multiline": false
}
```

### JSON structure

```json
{
  "check_values": false,
  "check_types": true,
  "ignore_extra_keys": true
}
```

## Example: full suite with mixed comparators

```json
{
  "suite_name": "mixed-eval",
  "default_comparator": "fuzzy",
  "default_threshold": 0.80,
  "gate_threshold": 0.90,
  "cases": [
    {
      "id": "factual-01",
      "input": "What is the capital of Japan?",
      "expected": "Tokyo",
      "actual": "The capital of Japan is Tokyo.",
      "comparator": "contains"
    },
    {
      "id": "numeric-01",
      "input": "What is pi to 4 decimal places?",
      "expected": "3.1416",
      "actual": "Pi is approximately 3.1415",
      "comparator": "numeric",
      "config": { "tolerance": 0.001 }
    },
    {
      "id": "format-01",
      "input": "Generate a valid email address",
      "expected": "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
      "actual": "user@example.com",
      "comparator": "regex"
    },
    {
      "id": "json-01",
      "input": "Return a user object with name, age, and active status",
      "expected": "{\"name\": \"\", \"age\": 0, \"active\": true}",
      "actual": "{\"name\": \"Alice\", \"age\": 28, \"active\": true}",
      "comparator": "json_structure",
      "config": { "check_types": true, "check_values": false }
    }
  ]
}
```
