# Comparator reference

Each comparator takes an `expected` value, an `actual` value, and an optional `config` object. It returns a score between 0.0 and 1.0.

## `exact`

Character-for-character match after normalization. Returns 1.0 on match, 0.0 otherwise.

**Config options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `case_insensitive` | bool | `true` | Lowercase both strings before comparing |
| `strip_whitespace` | bool | `true` | Collapse all whitespace runs to a single space |
| `strip_punctuation` | bool | `false` | Remove all non-alphanumeric, non-space characters |

**Example:**

```json
{
  "id": "exact-01",
  "expected": "Paris",
  "actual": "  paris  ",
  "comparator": "exact",
  "config": { "case_insensitive": true, "strip_whitespace": true }
}
```

Score: `1.0` (both normalize to "paris")

## `contains`

Checks whether the expected string appears as a substring of the actual output. Returns 1.0 if found, 0.0 otherwise. Useful when the LLM wraps the answer in a longer sentence.

**Config options:** Same as `exact` (normalization applied to both strings before the substring check).

**Example:**

```json
{
  "id": "contains-01",
  "expected": "42",
  "actual": "The answer is 42.",
  "comparator": "contains"
}
```

Score: `1.0` ("42" is found in "the answer is 42.")

## `fuzzy`

Levenshtein-distance-based similarity ratio: `1.0 - (edit_distance / max_length)`. Returns a continuous score between 0.0 and 1.0.

**Config options:** Same as `exact` (normalization applied before distance calculation).

**When to use:** The actual output is nearly correct but has minor typos, rephrasing, or extra filler words. Set the threshold to the minimum acceptable similarity — 0.8 is a reasonable starting point for short answers, 0.6 for longer paragraphs.

**Example:**

```json
{
  "id": "fuzzy-01",
  "expected": "The mitochondria is the powerhouse of the cell",
  "actual": "Mitochondria are the powerhouse of cells",
  "comparator": "fuzzy",
  "threshold": 0.75,
  "config": { "case_insensitive": true }
}
```

Score: ~`0.78` (minor wording differences, passes at 0.75 threshold)

## `numeric`

Extracts the first number from both expected and actual strings, then compares within a tolerance. Returns 1.0 if within tolerance, 0.0 otherwise.

**Config options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `tolerance` | float | `0.01` | Maximum allowed difference |
| `tolerance_type` | string | `"absolute"` | `"absolute"` or `"relative"`. Relative tolerance is computed as `abs(actual - expected) / abs(expected)`. |

**Examples:**

Absolute tolerance:
```json
{
  "id": "numeric-abs-01",
  "expected": "3.14159",
  "actual": "The value of pi is approximately 3.14",
  "comparator": "numeric",
  "config": { "tolerance": 0.01, "tolerance_type": "absolute" }
}
```

Score: `1.0` (difference is ~0.00159, within 0.01 tolerance)

Relative tolerance:
```json
{
  "id": "numeric-rel-01",
  "expected": "1000000",
  "actual": "The population is about 1,020,000",
  "comparator": "numeric",
  "config": { "tolerance": 0.05, "tolerance_type": "relative" }
}
```

Score: `1.0` (2% difference, within 5% relative tolerance)

## `regex`

Treats the `expected` field as a regex pattern and tests it against `actual`. Returns 1.0 if the pattern matches (search, not full match), 0.0 otherwise.

**Config options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `case_insensitive` | bool | `true` | Apply `re.IGNORECASE` flag |
| `dotall` | bool | `false` | Apply `re.DOTALL` flag (`.` matches newlines) |
| `multiline` | bool | `false` | Apply `re.MULTILINE` flag (`^`/`$` match line boundaries) |

**Example:**

```json
{
  "id": "regex-01",
  "expected": "\\b\\d{1,3}(\\.\\d{1,3}){3}\\b",
  "actual": "The server IP is 192.168.1.100 on port 8080",
  "comparator": "regex"
}
```

Score: `1.0` (IPv4 pattern matches in the actual string)

**Note:** The `expected` field IS the regex pattern. Escape backslashes properly in JSON (`\\d` not `\d`).

## `json_structure`

Parses both expected and actual as JSON, then compares structure (keys and types) and optionally values. Returns a continuous score: the fraction of expected fields that match.

**Config options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `check_values` | bool | `false` | Also compare leaf values for equality |
| `check_types` | bool | `true` | Require matching Python types at each leaf |
| `ignore_extra_keys` | bool | `true` | Don't penalize keys in actual that aren't in expected |

**Example — structure only:**

```json
{
  "id": "json-struct-01",
  "expected": "{\"name\": \"string\", \"age\": 0, \"active\": true}",
  "actual": "{\"name\": \"Alice\", \"age\": 30, \"active\": false, \"email\": \"a@b.com\"}",
  "comparator": "json_structure",
  "config": { "check_values": false, "check_types": true, "ignore_extra_keys": true }
}
```

Score: `1.0` (all three expected keys present with matching types; extra "email" key ignored)

**Example — structure + values:**

```json
{
  "id": "json-struct-02",
  "expected": "{\"status\": \"ok\", \"count\": 3}",
  "actual": "{\"status\": \"ok\", \"count\": 5}",
  "comparator": "json_structure",
  "config": { "check_values": true }
}
```

Score: `0.5` ("status" matches, "count" does not)

## `semantic`

Bag-of-words cosine similarity. Tokenizes both strings into words, builds frequency vectors, and computes the cosine of the angle between them. Returns a continuous score between 0.0 and 1.0.

**Config options:** Same as `exact` (normalization applied before tokenization).

**When to use:** The actual output conveys the same meaning using different word order or synonyms. This is a lightweight approximation — it catches word overlap but not true paraphrase detection. For short, keyword-rich answers it works well; for long narrative text, consider fuzzy matching instead.

**Example:**

```json
{
  "id": "semantic-01",
  "expected": "The quick brown fox jumps over the lazy dog",
  "actual": "A lazy dog was jumped over by the quick brown fox",
  "comparator": "semantic",
  "threshold": 0.7
}
```

Score: ~`0.86` (high word overlap despite different sentence structure)

## Choosing a comparator

| Situation | Recommended comparator |
|-----------|----------------------|
| Short factual answers (names, dates, single words) | `exact` or `contains` |
| Answers that may have minor wording variation | `fuzzy` (threshold 0.75-0.90) |
| Numeric extraction (prices, counts, measurements) | `numeric` with appropriate tolerance |
| Format validation (emails, IPs, dates, codes) | `regex` |
| Structured data (API responses, parsed objects) | `json_structure` |
| Meaning-equivalent but rephrased answers | `semantic` (threshold 0.65-0.85) |
| Long-form answers where key phrases must appear | `contains` (one case per required phrase) |
