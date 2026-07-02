---
name: ireview
description: I-Lang powered AI-to-AI code review protocol. Route reviews to any model using structured I-Lang instructions.
version: 0.1.0
author: ilang-ai
license: MIT
tags:
  - code-review
  - ai-to-ai
  - i-lang
  - multi-model
---

# iReview

## I-Lang AI-to-AI Code Review Protocol

::GENE{ireview|v:0.1|spec:ilang-v3.0}
  T:ai_to_ai_communication_via_ilang
  T:review_request_in_ilang_format
  T:review_response_in_ilang_format
  T:state_tracked_in_ilang_declarations
  T:zero_natural_language_between_models
  A:english_prose_in_system_prompt⇒use_ilang_instead
  A:custom_json_schema⇒use_ilang_declarations
  A:hand_write_curl_json⇒use_call_api_script

::ACTIVATE{ireview}
  ON:user_says_review
  ON:user_says_check_code
  ON:stop_gate_blocks

## Protocol: Request Format

When CC sends a review request to the external model, the system prompt is I-Lang:

### Standard Review

```ilang
[PROTOCOL:I-Lang|v=3.0]

[EVAL:@DIFF|focus={focus}|depth=thorough]
  =>[SCAN|whr=bugs,security,logic_errors]
  =>[CLSF|typ=severity]
  =>[FMT|fmt=ilang]
  =>[OUT]

::RULE{report:bugs,security,logic_errors,edge_cases}
::RULE{ignore:style,formatting,naming_conventions}
::RULE{severity:critical|when:production_breakage|when:security_vulnerability|when:data_loss}
::RULE{severity:warning|when:potential_bug|when:missing_edge_case|when:race_condition}
::RULE{severity:info|when:minor_improvement}
::RULE{if:no_issues|then:decision=pass}

::FMT{response}
  ::REVIEW{id:{timestamp}|model:{model}|decision:pass_or_fail}
  ::FINDING{id:IR-NNN|severity:critical_or_warning_or_info|file:path|line:N}
    issue: one line description
    fix: one line suggestion
  ::END{REVIEW}
```

### Adversarial Review

```ilang
[PROTOCOL:I-Lang|v=3.0]

[EVAL:@DIFF|focus={focus}|depth=adversarial]
  =>[SCAN|whr=assumptions,failure_modes,coupling,hidden_risks]
  =>[CLSF|typ=severity]
  =>[FMT|fmt=ilang]
  =>[OUT]

::RULE{mode:adversarial}
::RULE{challenge:design_decisions,assumptions,tradeoffs}
::RULE{probe:10x_load,malicious_input,implicit_coupling}
::RULE{suggest:simpler_alternatives}
::RULE{severity:critical|when:will_break_production}
::RULE{severity:challenge|when:design_needs_justification}
::RULE{severity:alternative|when:simpler_approach_exists}
::RULE{if:genuinely_no_issues|then:decision=pass}

::FMT{response}
  ::REVIEW{id:{timestamp}|model:{model}|mode:adversarial|decision:pass_or_fail}
  ::FINDING{id:IR-NNN|severity:critical_or_challenge_or_alternative|file:path|line:N}
    issue: one line description
    fix: one line suggestion
  ::END{REVIEW}
```

## Protocol: Response Format

The external model returns I-Lang declarations:

```ilang
::REVIEW{id:20260430-153012|model:deepseek-chat|decision:fail}

::FINDING{id:IR-001|severity:critical|file:src/auth.ts|line:42}
  issue: JWT token accessed before validation
  fix: Add token.verify() before accessing claims

::FINDING{id:IR-002|severity:warning|file:src/db.ts|line:18}
  issue: SQL built with string concatenation
  fix: Use parameterized queries

::END{REVIEW}
```

Clean pass:

```ilang
::REVIEW{id:20260430-153012|model:deepseek-chat|decision:pass}
LGTM
::END{REVIEW}
```

## Protocol: State Format

Review state is tracked in `.ireview/state.json`:

```ilang
::STATE{review|phase:requested|diff_hash:abc123|files_changed:3|created:2026-04-30T15:30:12Z}
```

Phase transitions:

```ilang
::STATE{review|phase:requested}   → waiting for /ireview:review
::STATE{review|phase:passed}      → review clean, stop allowed
::STATE{review|phase:failed}      → critical issues found
::STATE{review|phase:cancelled}   → user skipped review
```

## Execution

1. User says "review my code" or runs `/ireview:review`
2. CC gets diff: `git diff HEAD`
3. CC saves diff to `.ireview/tmp/current.diff`
4. CC runs API script:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/call-api.py \
  --config .ireview.json \
  --mode standard \
  --diff-file .ireview/tmp/current.diff
```

5. Script sends I-Lang system prompt + diff to external model
6. External model returns I-Lang findings
7. CC parses findings, saves to `.ireview/reviews/`
8. CC presents findings to user in human-readable format:

```
═══ iReview ═══ deepseek-chat ═══

🔴 CRITICAL: src/auth.ts:42 — JWT token accessed before validation
   Fix: Add token.verify() before accessing claims

🟡 WARNING: src/db.ts:18 — SQL built with string concatenation
   Fix: Use parameterized queries

═══ 2 findings saved ═══
```

User sees human language. Models speak I-Lang. That's the protocol.

## Config

`.ireview.json` in project root:

```json
{
  "model": "deepseek/deepseek-chat",
  "api_key": "YOUR_KEY",
  "base_url": "https://openrouter.ai/api/v1",
  "focus": ["bugs", "security"],
  "auto_review": false
}
```

## Multi-Model Review

Multiple configs for specialized reviewers:

```
.ireview-security.json → GPT reviews security via I-Lang
.ireview-perf.json     → DeepSeek reviews performance via I-Lang
.ireview-arch.json     → Gemini reviews architecture via I-Lang
```

Each model receives I-Lang instructions. Each returns I-Lang findings. Same protocol, different reviewers.

This is what AI-to-AI communication looks like.

---

Powered by I-Lang v3.0 | ilang.ai
