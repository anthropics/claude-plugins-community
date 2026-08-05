---
name: llm-eval
description: Evaluate LLM outputs against golden examples with tolerance-based scoring. Invoke this skill when the user wants to compare model outputs to expected answers, run eval suites, benchmark prompt quality, or gate deployments on output accuracy. Supports exact, fuzzy, numeric, regex, and JSON structure comparators.
---

# LLM Eval skill

This skill teaches Claude how to evaluate LLM outputs against golden reference examples using structured comparators and configurable scoring thresholds. It runs entirely within a Claude Code session using inline Python scripts — no external services or API keys required.

## When to invoke

- **Golden test evaluation** — "evaluate these outputs against my golden examples", "run my eval suite", "score these responses"
- **Prompt quality benchmarking** — "how well does this prompt perform on my test cases", "compare prompt A vs prompt B"
- **Pass/fail gating** — "do these outputs meet a 90% pass rate", "which test cases are failing"
- **Output comparison** — "compare this output to expected", "does this match within tolerance"
- **Regression testing** — "did the new prompt break any existing test cases"

Do NOT use for: generating golden examples from scratch (help the user write them instead), live API calls to external LLMs, or subjective quality ratings without defined criteria.

## Core concepts

### Test suite format

A test suite is a JSON file containing an array of test cases. Each case has an input, an expected output (the golden reference), an actual output (the LLM response to evaluate), and a comparator configuration.

```json
{
  "suite_name": "my-eval-suite",
  "description": "Description of what this suite tests",
  "default_comparator": "fuzzy",
  "default_threshold": 0.85,
  "cases": [
    {
      "id": "case-001",
      "input": "What is the capital of France?",
      "expected": "Paris",
      "actual": "The capital of France is Paris.",
      "comparator": "fuzzy",
      "threshold": 0.8,
      "tags": ["geography", "factual"]
    }
  ]
}
```

**Fields:**

| Field | Required | Description |
|---|---|---|
| `suite_name` | yes | Unique identifier for the suite |
| `description` | no | Human-readable description |
| `default_comparator` | no | Comparator used when a case doesn't specify one (default: `exact`) |
| `default_threshold` | no | Pass threshold when a case doesn't specify one (default: `1.0`) |
| `cases` | yes | Array of test case objects |
| `cases[].id` | yes | Unique identifier within the suite |
| `cases[].input` | no | The prompt or input that produced the output (for context/reporting) |
| `cases[].expected` | yes | The golden reference answer |
| `cases[].actual` | yes | The LLM output to evaluate |
| `cases[].comparator` | no | Override comparator for this case |
| `cases[].threshold` | no | Override pass threshold for this case |
| `cases[].tags` | no | Tags for filtering and grouping in reports |
| `cases[].config` | no | Comparator-specific configuration (see each comparator below) |

### Comparator types

See `references/comparators.md` for full documentation. Summary:

| Comparator | Score range | Use when |
|---|---|---|
| `exact` | 0.0 or 1.0 | Output must match expected character-for-character (after optional normalization) |
| `fuzzy` | 0.0 to 1.0 | Output should be similar; minor wording differences acceptable |
| `numeric` | 0.0 or 1.0 | Comparing extracted numbers within a tolerance |
| `regex` | 0.0 or 1.0 | Output must match a regex pattern defined in expected |
| `json_structure` | 0.0 to 1.0 | Comparing JSON objects — keys, types, and optionally values |
| `contains` | 0.0 or 1.0 | Output must contain the expected string as a substring |
| `semantic` | 0.0 to 1.0 | Bag-of-words cosine similarity for lightweight semantic comparison |

### Scoring

Each test case receives a **score** between 0.0 and 1.0 from its comparator. The case **passes** if `score >= threshold`. The suite-level pass rate is `passing_cases / total_cases`.

## Running an evaluation

When the user provides a test suite (as a JSON file or inline), follow this procedure:

### Step 1 — Validate the suite

Parse the JSON. Verify every case has `id`, `expected`, and `actual`. Fill in defaults for missing `comparator` and `threshold` from suite-level defaults, then from plugin-level defaults (`LLM_EVAL_DEFAULT_THRESHOLD`, `LLM_EVAL_FUZZY_RATIO`, `LLM_EVAL_NUMERIC_TOLERANCE` environment variables), then from hardcoded defaults.

### Step 2 — Run comparisons

Execute the evaluation by writing and running a Python script. The script must:

1. Load the test suite JSON
2. For each case, apply the appropriate comparator function
3. Compute per-case scores and pass/fail status
4. Compute suite-level aggregates

Use this Python evaluation script pattern:

```python
import json
import re
import math
import sys
from collections import Counter

def normalize(s, config=None):
    """Normalize a string for comparison."""
    config = config or {}
    s = str(s)
    if config.get("strip_whitespace", True):
        s = " ".join(s.split())
    if config.get("case_insensitive", True):
        s = s.lower()
    if config.get("strip_punctuation", False):
        s = re.sub(r'[^\w\s]', '', s)
    return s.strip()

def score_exact(expected, actual, config=None):
    config = config or {}
    e = normalize(expected, config)
    a = normalize(actual, config)
    return 1.0 if e == a else 0.0

def score_contains(expected, actual, config=None):
    config = config or {}
    e = normalize(expected, config)
    a = normalize(actual, config)
    return 1.0 if e in a else 0.0

def score_fuzzy(expected, actual, config=None):
    """Levenshtein-based similarity ratio."""
    config = config or {}
    e = normalize(expected, config)
    a = normalize(actual, config)
    if e == a:
        return 1.0
    len_e, len_a = len(e), len(a)
    if len_e == 0 or len_a == 0:
        return 0.0
    # Wagner-Fischer Levenshtein distance
    matrix = list(range(len_a + 1))
    for i in range(1, len_e + 1):
        prev, matrix[0] = matrix[0], i
        for j in range(1, len_a + 1):
            cost = 0 if e[i-1] == a[j-1] else 1
            temp = matrix[j]
            matrix[j] = min(matrix[j] + 1, matrix[j-1] + 1, prev + cost)
            prev = temp
    distance = matrix[len_a]
    max_len = max(len_e, len_a)
    return 1.0 - (distance / max_len)

def score_numeric(expected, actual, config=None):
    """Compare numeric values within tolerance."""
    config = config or {}
    tolerance = config.get("tolerance", 0.01)
    tolerance_type = config.get("tolerance_type", "absolute")  # absolute or relative
    try:
        nums_expected = [float(x) for x in re.findall(r'-?\d+\.?\d*(?:[eE][+-]?\d+)?', str(expected))]
        nums_actual = [float(x) for x in re.findall(r'-?\d+\.?\d*(?:[eE][+-]?\d+)?', str(actual))]
    except (ValueError, TypeError):
        return 0.0
    if not nums_expected or not nums_actual:
        return 0.0
    e_val = nums_expected[0]
    a_val = nums_actual[0]
    if tolerance_type == "relative":
        if e_val == 0:
            return 1.0 if a_val == 0 else 0.0
        diff = abs(a_val - e_val) / abs(e_val)
    else:
        diff = abs(a_val - e_val)
    return 1.0 if diff <= tolerance else 0.0

def score_regex(expected, actual, config=None):
    """Check if actual matches the regex pattern in expected."""
    config = config or {}
    flags = 0
    if config.get("case_insensitive", True):
        flags |= re.IGNORECASE
    if config.get("dotall", False):
        flags |= re.DOTALL
    if config.get("multiline", False):
        flags |= re.MULTILINE
    try:
        match = re.search(expected, str(actual), flags)
        return 1.0 if match else 0.0
    except re.error:
        return 0.0

def score_json_structure(expected, actual, config=None):
    """Compare JSON structures — keys, types, and optionally values."""
    config = config or {}
    check_values = config.get("check_values", False)
    check_types = config.get("check_types", True)
    ignore_extra_keys = config.get("ignore_extra_keys", True)
    try:
        e_obj = json.loads(expected) if isinstance(expected, str) else expected
        a_obj = json.loads(actual) if isinstance(actual, str) else actual
    except (json.JSONDecodeError, TypeError):
        return 0.0
    return _compare_json(e_obj, a_obj, check_values, check_types, ignore_extra_keys)

def _compare_json(expected, actual, check_values, check_types, ignore_extra_keys):
    if isinstance(expected, dict) and isinstance(actual, dict):
        if not expected:
            return 1.0
        scores = []
        for key in expected:
            if key not in actual:
                scores.append(0.0)
            else:
                scores.append(_compare_json(
                    expected[key], actual[key],
                    check_values, check_types, ignore_extra_keys
                ))
        if not ignore_extra_keys and len(actual) > len(expected):
            extra = len(actual) - len(expected)
            scores.extend([0.0] * extra)
        return sum(scores) / len(scores) if scores else 1.0
    elif isinstance(expected, list) and isinstance(actual, list):
        if not expected:
            return 1.0 if not actual else 0.0
        scores = []
        for i, e_item in enumerate(expected):
            if i < len(actual):
                scores.append(_compare_json(
                    e_item, actual[i],
                    check_values, check_types, ignore_extra_keys
                ))
            else:
                scores.append(0.0)
        return sum(scores) / len(scores) if scores else 1.0
    else:
        if check_types and type(expected) != type(actual):
            return 0.0
        if check_values:
            return 1.0 if expected == actual else 0.0
        return 1.0

def score_semantic(expected, actual, config=None):
    """Bag-of-words cosine similarity."""
    config = config or {}
    e = normalize(expected, config)
    a = normalize(actual, config)
    e_words = e.split()
    a_words = a.split()
    if not e_words or not a_words:
        return 0.0
    e_counter = Counter(e_words)
    a_counter = Counter(a_words)
    all_words = set(e_counter.keys()) | set(a_counter.keys())
    dot = sum(e_counter.get(w, 0) * a_counter.get(w, 0) for w in all_words)
    mag_e = math.sqrt(sum(v**2 for v in e_counter.values()))
    mag_a = math.sqrt(sum(v**2 for v in a_counter.values()))
    if mag_e == 0 or mag_a == 0:
        return 0.0
    return dot / (mag_e * mag_a)

COMPARATORS = {
    "exact": score_exact,
    "contains": score_contains,
    "fuzzy": score_fuzzy,
    "numeric": score_numeric,
    "regex": score_regex,
    "json_structure": score_json_structure,
    "semantic": score_semantic,
}

def evaluate_suite(suite_path):
    with open(suite_path) as f:
        suite = json.load(f)
    default_comp = suite.get("default_comparator", "exact")
    default_thresh = suite.get("default_threshold", 1.0)
    results = []
    for case in suite["cases"]:
        comp_name = case.get("comparator", default_comp)
        threshold = case.get("threshold", default_thresh)
        config = case.get("config", {})
        score_fn = COMPARATORS.get(comp_name, score_exact)
        score = score_fn(case["expected"], case["actual"], config)
        passed = score >= threshold
        results.append({
            "id": case["id"],
            "comparator": comp_name,
            "score": round(score, 4),
            "threshold": threshold,
            "passed": passed,
            "tags": case.get("tags", []),
        })
    passing = sum(1 for r in results if r["passed"])
    total = len(results)
    report = {
        "suite_name": suite.get("suite_name", "unnamed"),
        "total_cases": total,
        "passing": passing,
        "failing": total - passing,
        "pass_rate": round(passing / total, 4) if total > 0 else 0.0,
        "results": results,
    }
    return report

if __name__ == "__main__":
    suite_path = sys.argv[1]
    report = evaluate_suite(suite_path)
    print(json.dumps(report, indent=2))
```

### Step 3 — Generate the report

After running the script, present results in this format:

```
## Eval Report: {suite_name}

**Pass rate: {passing}/{total} ({pass_rate_pct}%)**

| ID | Comparator | Score | Threshold | Result |
|----|-----------|-------|-----------|--------|
| case-001 | fuzzy | 0.92 | 0.80 | PASS |
| case-002 | exact | 0.00 | 1.00 | FAIL |
| ... | ... | ... | ... | ... |

### Failing cases

**case-002** (exact, score: 0.00, threshold: 1.00)
- Expected: `...`
- Actual: `...`

### Summary by tag
| Tag | Cases | Passing | Rate |
|-----|-------|---------|------|
| geography | 5 | 4 | 80.0% |
| factual | 8 | 7 | 87.5% |
```

Always show the full results table, then expand only the failing cases with expected vs actual. Group by tags if tags are present.

### Step 4 — Gate check

If the user specified a minimum pass rate for the suite, compare the actual pass rate against it and clearly state whether the gate passed or failed:

```
Gate: 90% minimum pass rate
Result: FAIL (actual: 85.0%)
3 cases below threshold need attention.
```

## Working with user-provided data

### When the user has a JSON file

Read the file, validate the format, and run the evaluation directly.

### When the user provides examples inline

Construct the suite JSON from their description. Ask for clarification on:
- Which comparator to use (if not obvious from context)
- What threshold to apply
- Whether to normalize whitespace/case

### When the user wants to compare two prompt variants

Run both suites, then produce a side-by-side diff report showing which cases improved, regressed, or stayed the same.

## Configuration reference

See `references/config-schema.md` for the full configuration schema.
See `references/comparators.md` for detailed comparator documentation with examples.

## File index

```
SKILL.md                          <- you are here: core instructions + evaluation procedure
references/
   comparators.md                 <- detailed docs for each comparator type with examples
   config-schema.md               <- full configuration schema reference
```
