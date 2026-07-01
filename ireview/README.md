# iReview

> **AI-to-AI code review, powered by I-Lang protocol.**
> Any model reviews your code. Structured instructions in, structured findings out.
>
> I-Lang is the first protocol to formally map Greek mathematical symbols (Σ, Δ, φ, λ, Ω, ∇, μ, Π, ψ, ξ, ζ, θ, ∂) as primitive verbs for AI-to-AI communication, and the first to define a computable vector space for AI judgment (11 dimensions, 4 axioms).

[![License](https://img.shields.io/badge/license-MIT-d4a858?style=flat-square)](LICENSE)
[![Protocol](https://img.shields.io/badge/protocol-I--Lang_v3.0-d4a858?style=flat-square)](https://ilang.ai)
[![I-Lang L3](https://img.shields.io/badge/I--Lang-L3_Agent_Compatible-d4a858?style=flat-square)](https://github.com/ilang-ai/ilang-spec)

---

## Why

Every AI-to-AI code review tool today sends English prose between models. "You are a senior code reviewer. Please review this diff..." — and the response is unstructured text that has to be guessed and parsed.

iReview uses **I-Lang v3.0** as the communication protocol between models. Claude Code sends structured instructions:

```ilang
[EVAL:@DIFF|focus=security,bugs]=>[SCAN]=>[CLSF|typ=severity]=>[OUT]
```

The review model returns structured declarations:

```ilang
::REVIEW{id:20260430|model:deepseek-chat|decision:fail}
::FINDING{id:IR-001|severity:critical|file:src/auth.ts|line:42}
  issue: JWT token accessed before validation
  fix: Add token.verify() before accessing claims
::END{REVIEW}
```

Two AIs speaking a protocol. Not prose. Not guesswork. Parseable, repeatable, model-agnostic.

| | iReview | codex-plugin-cc |
|---|---|---|
| Install | One config file | Codex CLI + ChatGPT login |
| Models | Any OpenAI-compatible API | OpenAI only |
| Dependencies | Git + Bash + Python3 | Node.js 18.18+ + Codex CLI |
| Review modes | Standard + Adversarial | Standard + Adversarial + Background |
| Multi-model | Yes (chain security→perf→arch) | No |
| Protocol | I-Lang structured declarations | English prose |
| Cross-tool | CC + Cursor + Codex + Copilot + Gemini | Claude Code only |
| Stop gate | Diff-hash aware (no infinite loop) | Full state machine |

## Requirements

- `python3` (for reliable JSON handling in API calls)
- `git`
- `curl` or `urllib` (Python stdlib)

## Install (seconds)

```bash
/plugin marketplace add ilang-ai/iReview
/plugin install ireview@ilang-plugins
```

Create your config:

```bash
cp .ireview.example.json .ireview.json
# Set model and api_key — two fields, done
```

Or run `/ireview:setup` for interactive configuration.

## Config

```json
{
  "model": "deepseek/deepseek-chat",
  "api_key": "",
  "base_url": "https://openrouter.ai/api/v1",
  "focus": ["bugs", "security"],
  "auto_review": false
}
```

API key priority: `CLAUDE_PLUGIN_OPTION_API_KEY` > `IREVIEW_API_KEY` env var > `api_key` field in config.

| Provider | model | base_url |
|---|---|---|
| OpenRouter (any model) | `deepseek/deepseek-chat` | `https://openrouter.ai/api/v1` |
| DeepSeek direct | `deepseek-chat` | `https://api.deepseek.com/v1` |
| OpenAI direct | `gpt-4o` | `https://api.openai.com/v1` |
| Local Ollama | `llama3` | `http://localhost:11434/v1` |

**Change model = change one line.**

## Commands

```bash
/ireview:review                    # Review uncommitted changes
/ireview:review --base main        # Review branch vs main
/ireview:review --full             # Run all .ireview-*.json configs
/ireview:adversarial               # Devil's advocate review
/ireview:setup                     # Interactive configuration
/ireview:status                    # Review history and unresolved findings
/ireview:result                    # Show latest review details
/ireview:cancel                    # Cancel pending review, allow stop
```

## Auto Review Gate

Set `"auto_review": true` in config. When the session stops:

1. Stop hook detects file changes and computes diff hash
2. If this diff wasn't reviewed yet: blocks stop with instructions
3. You run `/ireview:review` — review executes, results saved
4. On next stop: diff hash matches passed review — stop allowed

**No infinite loops.** Diff-hash tracking ensures the same changes aren't re-reviewed.

## Multi-Model Review

```bash
echo '{"model":"gpt-4o","api_key":"sk-xxx","base_url":"https://api.openai.com/v1","focus":["security"]}' > .ireview-security.json
echo '{"model":"deepseek-chat","api_key":"sk-xxx","base_url":"https://api.deepseek.com/v1","focus":["performance"]}' > .ireview-perf.json
```

`/ireview:review --full` — runs all configs. Each produces its own review file.

## Architecture

```
You ──→ Claude Code ──I-Lang──→ Review Model ──I-Lang──→ Claude Code ──→ You
         (implementer)           (reviewer)              (presents findings)
```

```
hooks/stop-gate.sh     ← Fast gating. Checks diff hash, blocks or allows.
scripts/call-api.py    ← I-Lang protocol layer. Sends I-Lang instructions,
                         parses I-Lang responses. Falls back to JSON/text.
commands/*.md           ← Slash commands. Orchestrate the review flow.
skills/ireview/SKILL.md ← Protocol definition. I-Lang request/response formats.
```

The key insight: API calls go through `call-api.py` which sends I-Lang instructions as system prompts and parses `::REVIEW{}`/`::FINDING{}` responses. Models that understand I-Lang return structured declarations. Models that don't return JSON or text, and the script handles the fallback. Either way, the protocol is the interface.

## Works Across Tools

| Tool | File | Hook support |
|---|---|---|
| Claude Code | `CLAUDE.md` | Full (stop gate + commands) |
| Cursor | `.cursorrules` | Manual review only |
| Codex | `AGENTS.md` | Manual review only |
| Copilot | `.github/copilot-instructions.md` | Manual review only |
| Gemini CLI | `GEMINI.md` | Manual review only |

## Privacy

Your code goes to whatever API you configure. iReview collects nothing. For private code, use local Ollama.

Add `.ireview.json` to `.gitignore` — it contains your API key.

## License

MIT

---

<sub>Built by <a href="https://ilang.ai">I-Lang Protocol</a> · The native language of artificial intelligence</sub>
