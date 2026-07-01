#!/usr/bin/env node

import fs from "node:fs"
import path from "node:path"
import os from "node:os"
import readline from "node:readline/promises"
import { $ } from "execa"
import ora from "ora"

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------

const EVAL_DIR = path.dirname(new URL(import.meta.url).pathname)
const SKILL_DIR = path.resolve(EVAL_DIR, "..")

// ---------------------------------------------------------------------------
// Model selection — null means use CLI default
// ---------------------------------------------------------------------------

const modelFlag = process.argv.indexOf("--model")
const MODEL = modelFlag !== -1 ? process.argv[modelFlag + 1] : null

// ---------------------------------------------------------------------------
// User input helpers
// ---------------------------------------------------------------------------

async function confirm(message) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout })
  const answer = await rl.question(`${message} (y/N): `)
  rl.close()
  return answer.toLowerCase() === "y" || answer.toLowerCase() === "yes"
}

async function prompt(message) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout })
  const answer = await rl.question(`${message} `)
  rl.close()
  return answer.trim()
}

// ---------------------------------------------------------------------------
// File scanning
// ---------------------------------------------------------------------------

const SOURCE_EXTENSIONS = new Set([
  ".js", ".ts", ".jsx", ".tsx", ".mjs", ".cjs",
  ".swift", ".kt", ".java", ".cs", ".go", ".py", ".rb", ".php", ".dart",
  ".vue", ".svelte", ".astro",
  ".gradle", ".kts",
  ".xml", ".plist", ".json", ".env", ".yaml", ".yml", ".toml", ".properties",
  ".html", ".css", ".scss",
  ".csproj", ".sln",
  ".lock",
  ".pbxproj", ".resolved", ".podspec",
])

function collectSourceFiles(dir, files = []) {
  if (!fs.existsSync(dir)) return files
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      if (entry.name === "node_modules" || entry.name === ".git" || entry.name === "build" || entry.name === "dist" || entry.name === ".gradle") continue
      collectSourceFiles(full, files)
    } else if (SOURCE_EXTENSIONS.has(path.extname(entry.name))) {
      files.push(full)
    }
  }
  return files
}

function readAllSources(dir) {
  const files = collectSourceFiles(dir)
  const contents = []
  for (const f of files) {
    try {
      contents.push({ path: f, content: fs.readFileSync(f, "utf-8") })
    } catch {
      // skip unreadable files
    }
  }
  return contents
}

// ---------------------------------------------------------------------------
// Grader execution
// ---------------------------------------------------------------------------

function gradeFileContains(grader, workspaceDir) {
  // Glob for files matching the pattern in the workspace
  const pattern = grader.file_pattern
  const matchingFiles = []

  function walkAndMatch(dir, globPattern) {
    // Convert simple glob to check function
    // Supports: **/.env*, **/strings.xml, **/appsettings*.json, **/*.plist, **/environment*.ts, **/application*.properties
    const filename = globPattern.replace(/^\*\*\//, "")
    const isWildcard = filename.includes("*")

    function matchesPattern(name) {
      if (!isWildcard) return name === filename
      // Escape regex-special chars, then convert * to [^/]*
      const escaped = filename.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, "[^/]*")
      const regex = new RegExp("^" + escaped + "$")
      return regex.test(name)
    }

    if (!fs.existsSync(dir)) return
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name)
      if (entry.isDirectory()) {
        if (["node_modules", ".git", "build", "dist", ".gradle"].includes(entry.name)) continue
        walkAndMatch(full, globPattern)
      } else if (matchesPattern(entry.name)) {
        try {
          matchingFiles.push({ path: full, content: fs.readFileSync(full, "utf-8") })
        } catch { /* skip unreadable */ }
      }
    }
  }

  walkAndMatch(workspaceDir, pattern)

  if (matchingFiles.length === 0) {
    return { pass: false, detail: `No files matching "${pattern}" found in workspace` }
  }

  for (const f of matchingFiles) {
    if (f.content.includes(grader.value)) {
      return { pass: true, detail: `Found "${grader.value}" in ${path.relative(workspaceDir, f.path)}` }
    }
  }

  const fileNames = matchingFiles.map((f) => path.relative(workspaceDir, f.path)).join(", ")
  return { pass: false, detail: `"${grader.value}" not found in matching files: ${fileNames}` }
}

function gradeContains(grader, sources) {
  for (const src of sources) {
    if (src.content.toLowerCase().includes(grader.value.toLowerCase())) {
      return { pass: true, detail: `Found "${grader.value}" in ${path.basename(src.path)}` }
    }
  }
  return { pass: false, detail: `"${grader.value}" not found in any source file` }
}

function gradeContainsAny(grader, sources) {
  // Pass if ANY of the values is found in any source file
  const allContent = sources.map((s) => s.content.toLowerCase()).join("\n")
  for (const value of grader.values) {
    if (allContent.includes(value.toLowerCase())) {
      return { pass: true, detail: `Found "${value}" in workspace` }
    }
  }
  return { pass: false, detail: `None of [${grader.values.join(", ")}] found in any source file` }
}

function gradeNotContains(grader, sources) {
  for (const src of sources) {
    if (src.content.toLowerCase().includes(grader.value.toLowerCase())) {
      return { pass: false, detail: `Found "${grader.value}" in ${path.basename(src.path)} (should not be present)` }
    }
  }
  return { pass: true, detail: `"${grader.value}" correctly absent` }
}

function gradeNotContainsAny(grader, sources) {
  // Pass only if NONE of the values is found in any source file
  for (const src of sources) {
    const lower = src.content.toLowerCase()
    for (const value of grader.values) {
      if (lower.includes(value.toLowerCase())) {
        return { pass: false, detail: `Found "${value}" in ${path.basename(src.path)} (should not be present)` }
      }
    }
  }
  return { pass: true, detail: `None of [${grader.values.join(", ")}] found (correct)` }
}

function gradeMatches(grader, sources) {
  let regex
  try {
    regex = new RegExp(grader.pattern)
  } catch {
    return { pass: false, detail: `Invalid regex pattern: ${grader.pattern}` }
  }
  for (const src of sources) {
    if (regex.test(src.content)) {
      return { pass: true, detail: `Pattern matched in ${path.basename(src.path)}` }
    }
  }
  return { pass: false, detail: `Pattern /${grader.pattern}/ not matched in any source file` }
}

function gradeAll(grader, sources, workspaceDir) {
  // Pass only if ALL sub-graders pass
  const subResults = []
  for (const sub of grader.graders) {
    const result = gradeSync(sub, sources, workspaceDir)
    subResults.push(result)
    if (!result.pass) {
      return { pass: false, detail: `Sub-grader failed: ${sub.description || sub.type} — ${result.detail}` }
    }
  }
  return { pass: true, detail: `All ${grader.graders.length} sub-graders passed` }
}

function gradeSync(grader, sources, workspaceDir) {
  // Synchronous grader dispatch (for use in all/any composites — excludes judge)
  switch (grader.type) {
    case "contains": return gradeContains(grader, sources)
    case "contains_any": return gradeContainsAny(grader, sources)
    case "file_contains": return gradeFileContains(grader, workspaceDir)
    case "not_contains": return gradeNotContains(grader, sources)
    case "not_contains_any": return gradeNotContainsAny(grader, sources)
    case "matches": return gradeMatches(grader, sources)
    default: return { pass: false, detail: `Unsupported sub-grader type: ${grader.type}` }
  }
}

async function gradeJudge(grader, sources, workspaceDir) {
  // Collect a summary of the workspace files for the judge
  const fileSummary = sources
    .slice(0, 20) // limit to 20 files to avoid context overflow
    .map((s) => `--- ${path.relative(workspaceDir, s.path)} ---\n${s.content.slice(0, 3000)}`)
    .join("\n\n")

  // Build judge prompt — include examples if provided (few-shot)
  let questionBlock = grader.question
  if (grader.examples) {
    questionBlock += `\n\n## Examples\n${grader.examples}`
  }

  const judgePrompt = `You are evaluating code quality. Review the following source files and answer this question:

${questionBlock}

Answer with exactly "YES" or "NO" on the first line, followed by a brief explanation.

${fileSummary}`

  const judgeArgs = ["-p", judgePrompt, "--permission-mode", "dontAsk", "--no-session-persistence"]
  if (MODEL) judgeArgs.push("--model", MODEL)

  try {
    const { stdout } = await $({
      timeout: 60000,
    })`claude ${judgeArgs}`
    const firstLine = stdout.trim().split("\n")[0].toUpperCase()
    const pass = firstLine.startsWith("YES")
    return { pass, detail: stdout.trim().slice(0, 300) }
  } catch (e) {
    return { pass: false, detail: `Judge failed: ${e.message}` }
  }
}

async function runGraders(graders, workspaceDir) {
  const sources = readAllSources(workspaceDir)
  const results = []

  // First pass: run all graders
  for (const grader of graders) {
    let result
    switch (grader.type) {
      case "contains":
        result = gradeContains(grader, sources)
        break
      case "contains_any":
        result = gradeContainsAny(grader, sources)
        break
      case "file_contains":
        result = gradeFileContains(grader, workspaceDir)
        break
      case "not_contains":
        result = gradeNotContains(grader, sources)
        break
      case "not_contains_any":
        result = gradeNotContainsAny(grader, sources)
        break
      case "matches":
        result = gradeMatches(grader, sources)
        break
      case "all":
        result = gradeAll(grader, sources, workspaceDir)
        break
      case "judge":
        result = await gradeJudge(grader, sources, workspaceDir)
        break
      default:
        result = { pass: false, detail: `Unknown grader type: ${grader.type}` }
    }

    results.push({
      type: grader.type,
      description: grader.description,
      ...result,
    })
  }

  // Second pass: invalidate not_contains passes when no positive graders passed.
  // If the agent wrote zero integration code, not_contains graders trivially pass
  // (nothing bad can be present when nothing is present). This inflates scores for
  // empty/untouched workspaces. Demote these to FAIL with an explanatory detail.
  const positiveTypes = new Set(["contains", "contains_any", "file_contains", "matches"])
  const anyPositivePassed = results.some((r) => positiveTypes.has(r.type) && r.pass)

  if (!anyPositivePassed) {
    for (const r of results) {
      if ((r.type === "not_contains" || r.type === "not_contains_any") && r.pass) {
        r.pass = false
        r.detail = `Invalidated: no positive graders passed (agent likely wrote no integration code). Original: ${r.detail}`
      }
    }
  }

  return results
}

// ---------------------------------------------------------------------------
// Token parsing
// ---------------------------------------------------------------------------

function parseTokenUsage(stdout) {
  // Try to parse token usage from claude CLI output
  // claude CLI outputs a summary line like: "Total tokens: 12345" or JSON with token info
  let tokens = 0
  try {
    // Try JSON output format first
    const jsonMatch = stdout.match(/"total_tokens"\s*:\s*(\d+)/)
    if (jsonMatch) {
      tokens = parseInt(jsonMatch[1], 10)
    } else {
      // Try summary line format
      const lineMatch = stdout.match(/[Tt]otal\s+tokens?\s*[=:]\s*([\d,]+)/)
      if (lineMatch) {
        tokens = parseInt(lineMatch[1].replace(/,/g, ""), 10)
      } else {
        // Try cost line (tokens in parentheses)
        const costMatch = stdout.match(/(\d[\d,]*)\s*tokens?\s*(?:used|total|consumed)/i)
        if (costMatch) {
          tokens = parseInt(costMatch[1].replace(/,/g, ""), 10)
        }
      }
    }
  } catch {
    // If parsing fails, return 0
  }
  return tokens
}

// ---------------------------------------------------------------------------
// Baseline mode — extract code blocks from LLM response
// ---------------------------------------------------------------------------

function extractCodeBlocks(text) {
  // Extract fenced code blocks with optional filename hints
  const blocks = []
  const regex = /```(\w+)?(?:\s+(?:\/\/|#|<!--)\s*(.+?))?[\r\n]+([\s\S]*?)```/g
  let match
  while ((match = regex.exec(text)) !== null) {
    const lang = match[1] || ""
    const hint = (match[2] || "").trim()
    const content = match[3].trim()
    blocks.push({ lang, hint, content })
  }
  return blocks
}

function writeCodeBlocksToWorkspace(blocks, workspaceDir) {
  // Write extracted code blocks to workspace files for grading
  // Use filename hints if available, otherwise generate names from language
  const langExtensions = {
    swift: ".swift", kotlin: ".kt", java: ".java", javascript: ".js", js: ".js",
    typescript: ".ts", ts: ".ts", jsx: ".jsx", tsx: ".tsx",
    python: ".py", ruby: ".rb", php: ".php", go: ".go",
    csharp: ".cs", cs: ".cs", xml: ".xml", json: ".json",
    html: ".html", css: ".css", yaml: ".yml", toml: ".toml",
    properties: ".properties", env: ".env", plist: ".plist",
  }

  let fileIndex = 0
  for (const block of blocks) {
    const ext = langExtensions[block.lang.toLowerCase()] || ".txt"
    // Use hint as filename if it looks like a path
    let filename = block.hint && block.hint.includes(".")
      ? block.hint
      : `block_${fileIndex}${ext}`

    // Prevent path traversal — resolve and verify it stays within workspace
    const resolvedWorkspace = path.resolve(workspaceDir)
    let filePath = path.resolve(workspaceDir, filename)
    if (!filePath.startsWith(resolvedWorkspace + path.sep) && filePath !== resolvedWorkspace) {
      filename = `block_${fileIndex}${ext}`
      filePath = path.resolve(workspaceDir, filename)
    }
    const dir = path.dirname(filePath)
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true })
    fs.writeFileSync(filePath, block.content)
    fileIndex++
  }
}

// ---------------------------------------------------------------------------
// Claude CLI runner
// ---------------------------------------------------------------------------

async function checkClaudeCli() {
  try {
    await $({ timeout: 10000 })`claude --version`
    return true
  } catch {
    return false
  }
}

async function runClaude(taskPrompt, workspaceDir, systemPrompt = null) {
  const args = [
    "-p", taskPrompt,
    "--permission-mode", "dontAsk",
    "--no-session-persistence",
    "--allowedTools", "Bash,Read,Write,Edit,Glob,Grep,WebFetch",
  ]
  if (MODEL) args.push("--model", MODEL)
  if (systemPrompt) {
    args.push("--append-system-prompt", systemPrompt)
  }

  const startTime = Date.now()
  const { stdout } = await $({
    cwd: workspaceDir,
    timeout: 600000, // 10 minutes max per run
    reject: false,
  })`claude ${args}`
  const durationMs = Date.now() - startTime
  const tokens = parseTokenUsage(stdout)

  return { stdout, durationMs, tokens }
}

async function runBaseline(taskPrompt, workspaceDir) {
  // Single LLM call — no tools, no skill context
  const args = [
    "-p", taskPrompt,
    "--permission-mode", "dontAsk",
    "--no-session-persistence",
    // No --allowedTools = no tool access
  ]
  if (MODEL) args.push("--model", MODEL)

  const startTime = Date.now()
  const { stdout } = await $({
    cwd: workspaceDir,
    timeout: 120000, // 2 minutes max for single call
    reject: false,
  })`claude ${args}`
  const durationMs = Date.now() - startTime
  const tokens = parseTokenUsage(stdout)

  // Extract code blocks from response and write to workspace for grading
  const blocks = extractCodeBlocks(stdout)
  if (blocks.length > 0) {
    writeCodeBlocksToWorkspace(blocks, workspaceDir)
  }

  return { stdout, durationMs, tokens }
}

// ---------------------------------------------------------------------------
// Results display
// ---------------------------------------------------------------------------

function displayResults(label, results) {
  const passed = results.filter((r) => r.pass).length
  const total = results.length
  const rate = ((passed / total) * 100).toFixed(0)

  console.log(`\n  ${label}: ${passed}/${total} passed (${rate}%)\n`)

  for (const r of results) {
    const icon = r.pass ? "  PASS" : "  FAIL"
    console.log(`  ${icon}  [${r.type}] ${r.description}`)
    if (!r.pass) {
      console.log(`         ${r.detail}`)
    }
  }
}

function analyzeGraderDeltas(withoutResults, withResults) {
  const analysis = {
    skill_wins: [],      // fail → pass (skill adding value)
    always_pass: [],     // pass in both (non-discriminating)
    always_fail: [],     // fail in both (broken or too hard)
    skill_regressions: [],// pass → fail (skill causing harm)
  }

  for (let i = 0; i < withoutResults.length; i++) {
    const wo = withoutResults[i]
    const wi = withResults[i]
    const entry = { index: i, type: wo.type, description: wo.description }

    if (!wo.pass && wi.pass) analysis.skill_wins.push(entry)
    else if (wo.pass && wi.pass) analysis.always_pass.push(entry)
    else if (!wo.pass && !wi.pass) analysis.always_fail.push(entry)
    else if (wo.pass && !wi.pass) analysis.skill_regressions.push(entry)
  }

  return analysis
}

function computeBenchmark(allRuns, config) {
  // allRuns: { baseline?: [{ results, durationMs, tokens }], without_skill: [...], with_skill: [...] }
  const total = config.graders_total || allRuns.without_skill[0].results.length

  const mean = (arr) => arr.length === 0 ? 0 : arr.reduce((a, b) => a + b, 0) / arr.length
  const stddev = (arr) => {
    if (arr.length <= 1) return 0
    const m = mean(arr)
    return Math.sqrt(arr.reduce((sum, v) => sum + (v - m) ** 2, 0) / arr.length)
  }

  function summarizeRuns(runs, filterFn = null) {
    if (!runs || runs.length === 0) return null
    const filteredResults = filterFn
      ? runs.map((r) => ({ ...r, results: r.results.filter(filterFn) }))
      : runs
    const countTotal = filterFn ? filteredResults[0].results.length : total
    if (countTotal === 0) return { pass_rate: { mean: 0, stddev: 0 }, runs: runs.length }
    const passRates = filteredResults.map((r) => r.results.filter((g) => g.pass).length / countTotal)
    const durations = runs.map((r) => r.durationMs / 1000)
    const tokenCounts = runs.map((r) => r.tokens || 0).filter((t) => t > 0)
    const result = {
      pass_rate: { mean: mean(passRates), stddev: stddev(passRates) },
      time_seconds: { mean: mean(durations), stddev: stddev(durations) },
      runs: runs.length,
      total: countTotal,
      details: filteredResults.map((r, i) => ({
        pass_rate: r.results.filter((g) => g.pass).length / countTotal,
        passed: r.results.filter((g) => g.pass).length,
        total: countTotal,
        duration_seconds: runs[i].durationMs / 1000,
        tokens: runs[i].tokens || 0,
      })),
    }
    if (tokenCounts.length > 0) {
      result.tokens = { mean: mean(tokenCounts), stddev: stddev(tokenCounts) }
    }
    return result
  }

  const baselineSummary = summarizeRuns(allRuns.baseline)
  const withoutSummary = summarizeRuns(allRuns.without_skill)
  const withSummary = summarizeRuns(allRuns.with_skill)

  // Primary delta: without_skill → with_skill (skill value)
  const skillDelta = withSummary.pass_rate.mean - withoutSummary.pass_rate.mean

  // Per-grader delta analysis (uses first run of each for comparison)
  const graderAnalysis = analyzeGraderDeltas(
    allRuns.without_skill[0].results,
    allRuns.with_skill[0].results
  )

  // Build delta object
  const delta = {
    without_skill_to_with_skill: skillDelta,
    time_seconds: withSummary.time_seconds.mean - withoutSummary.time_seconds.mean,
  }
  if (baselineSummary) {
    delta.baseline_to_without_skill = withoutSummary.pass_rate.mean - baselineSummary.pass_rate.mean
    delta.baseline_to_with_skill = withSummary.pass_rate.mean - baselineSummary.pass_rate.mean
  }

  // Build run_summary
  const runSummary = { without_skill: withoutSummary, with_skill: withSummary, delta }
  if (baselineSummary) runSummary.baseline = baselineSummary

  return {
    metadata: {
      ...config.metadata,
      run_date: new Date().toISOString(),
      total_graders: total,
      runs_per_configuration: allRuns.without_skill.length,
      baseline_included: !!baselineSummary,
    },
    run_summary: runSummary,
    grader_analysis: graderAnalysis,
    assessment: skillDelta >= 0.25
      ? "skill_valuable"
      : withSummary.pass_rate.mean >= 0.85
        ? "skill_acceptable"
        : skillDelta < 0.15
          ? "needs_improvement"
          : "moderate_value",
  }
}

// ---------------------------------------------------------------------------
// Feedback generation
// ---------------------------------------------------------------------------

function generateFeedback(benchmark, graders) {
  const ga = benchmark.grader_analysis
  const rs = benchmark.run_summary

  // Broken graders: always_fail
  const brokenGraders = ga.always_fail.map((g) => {
    let reason = "Both configs fail this grader."
    if (g.type === "matches") reason += " Check if regex pattern matches actual output. Verify file extension is in SOURCE_EXTENSIONS."
    if (g.type === "file_contains") reason += " Check if config file is created and contains the expected value."
    if (g.type === "judge") reason += " Review judge question — may be too strict or ambiguous."
    return { index: g.index, description: g.description, type: g.type, reason }
  })

  // Non-discriminating: always_pass graders (don't contribute to delta)
  const nonDiscriminating = ga.always_pass.map((g) => ({
    index: g.index,
    description: g.description,
    reason: "Both configs pass — this grader doesn't contribute to the skill delta.",
  }))

  // Skill gaps
  const skillGaps = []
  if (ga.always_fail.length > 0) {
    skillGaps.push({
      description: `${ga.always_fail.length} graders always fail. Fixing these would increase the visible delta.`,
    })
  }
  if (ga.skill_wins.length < 2) {
    skillGaps.push({
      description: "Few skill_wins. Consider adding more advanced pattern graders from SKILL.md.",
    })
  }

  // Regressions
  const regressions = ga.skill_regressions.map((g) => ({
    index: g.index,
    description: g.description,
    reason: "Passes without skill but fails with skill — the skill is causing harm for this grader. Investigate SKILL.md guidance.",
  }))

  // Token analysis
  const tokenAnalysis = {}
  if (rs.baseline && rs.baseline.tokens) tokenAnalysis.baseline_tokens = Math.round(rs.baseline.tokens.mean)
  if (rs.without_skill.tokens) tokenAnalysis.without_skill_tokens = Math.round(rs.without_skill.tokens.mean)
  if (rs.with_skill.tokens) tokenAnalysis.with_skill_tokens = Math.round(rs.with_skill.tokens.mean)
  if (tokenAnalysis.without_skill_tokens && tokenAnalysis.with_skill_tokens) {
    const diff = tokenAnalysis.without_skill_tokens - tokenAnalysis.with_skill_tokens
    const pct = Math.round((diff / tokenAnalysis.without_skill_tokens) * 100)
    tokenAnalysis.insight = diff > 0
      ? `Skill reduces token usage by ${pct}% — agent is more directed with skill guidance.`
      : `Skill increases token usage by ${Math.abs(pct)}% — SKILL.md may be too verbose or causing the agent to explore more.`
  }

  // Suggested actions (priority ordered)
  const suggestedActions = []
  if (regressions.length > 0) {
    suggestedActions.push({ priority: "critical", action: `Investigate ${regressions.length} regression(s) — skill is causing harm` })
  }
  if (brokenGraders.length > 0) {
    suggestedActions.push({ priority: "high", action: `Fix ${brokenGraders.length} always-fail grader(s) — check SOURCE_EXTENSIONS and regex patterns` })
  }
  if (nonDiscriminating.length > 0) {
    suggestedActions.push({ priority: "medium", action: `Review ${nonDiscriminating.length} non-discriminating grader(s) that don't contribute to delta` })
  }
  if (benchmark.assessment === "needs_improvement") {
    suggestedActions.push({ priority: "medium", action: "Skill delta is below 15% — strengthen SKILL.md with more advanced patterns" })
  }
  if (skillGaps.length > 0 && benchmark.assessment !== "skill_valuable") {
    suggestedActions.push({ priority: "low", action: "Add more advanced pattern graders from SKILL.md to increase delta" })
  }

  // Summary
  const delta = rs.delta.without_skill_to_with_skill
  const summaryParts = [`Skill adds ${delta >= 0 ? "+" : ""}${(delta * 100).toFixed(0)}% delta.`]
  if (ga.always_fail.length > 0) summaryParts.push(`${ga.always_fail.length} graders always fail.`)
  if (ga.skill_wins.length > 0) summaryParts.push(`${ga.skill_wins.length} skill wins.`)
  if (nonDiscriminating.length > 0) summaryParts.push(`${nonDiscriminating.length} graders are non-discriminating.`)

  return {
    generated_at: new Date().toISOString(),
    skill_name: benchmark.metadata.skill_name,
    assessment: benchmark.assessment,
    summary: summaryParts.join(" "),
    broken_graders: brokenGraders,
    non_discriminating: nonDiscriminating,
    skill_gaps: skillGaps,
    regressions,
    token_analysis: tokenAnalysis,
    suggested_actions: suggestedActions,
    user_notes: "",
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Dry-run: validate graders without running agents
// ---------------------------------------------------------------------------

function dryRunGraders(graders) {
  console.log("\n  Dry Run: Validating grader definitions\n")

  let errors = 0
  let warnings = 0
  console.log(`  Total: ${graders.length} graders\n`)

  for (let i = 0; i < graders.length; i++) {
    const g = graders[i]
    const prefix = `  [${i}] [${g.type}] ${g.description || "(no description)"}`

    // Check required fields
    if (!g.type) {
      console.log(`  FAIL ${prefix} — missing 'type' field`)
      errors++
      continue
    }
    if (!g.description) {
      console.log(`  WARN ${prefix} — missing 'description'`)
      warnings++
    }

    // Type-specific validation
    switch (g.type) {
      case "contains":
      case "not_contains":
        if (!g.value || g.value.trim() === "") {
          console.log(`  FAIL ${prefix} — empty 'value'`)
          errors++
        } else if (g.value.includes("{") && g.value.includes("}")) {
          console.log(`  FAIL ${prefix} — unsubstituted placeholder: ${g.value}`)
          errors++
        } else {
          console.log(`  PASS ${prefix} — value: "${g.value.slice(0, 60)}"`)
        }
        break

      case "contains_any":
      case "not_contains_any":
        if (!g.values || !Array.isArray(g.values) || g.values.length === 0) {
          console.log(`  FAIL ${prefix} — missing or empty 'values' array`)
          errors++
        } else {
          const hasPlaceholder = g.values.some((v) => v.includes("{") && v.includes("}"))
          if (hasPlaceholder) {
            console.log(`  FAIL ${prefix} — unsubstituted placeholder in values`)
            errors++
          } else {
            console.log(`  PASS ${prefix} — ${g.values.length} values: [${g.values.map((v) => `"${v.slice(0, 30)}"`).join(", ")}]`)
          }
        }
        break

      case "matches":
        if (!g.pattern) {
          console.log(`  FAIL ${prefix} — missing 'pattern'`)
          errors++
        } else {
          try {
            new RegExp(g.pattern)
            if (g.pattern.includes("{") && g.pattern.includes("}") && !g.pattern.includes("\\{")) {
              console.log(`  FAIL ${prefix} — unsubstituted placeholder in pattern: ${g.pattern.slice(0, 60)}`)
              errors++
            } else {
              console.log(`  PASS ${prefix} — regex: /${g.pattern.slice(0, 60)}/`)
            }
          } catch (e) {
            console.log(`  FAIL ${prefix} — invalid regex: ${e.message}`)
            errors++
          }
        }
        break

      case "file_contains":
        if (!g.file_pattern) {
          console.log(`  FAIL ${prefix} — missing 'file_pattern'`)
          errors++
        } else if (!g.value) {
          console.log(`  FAIL ${prefix} — missing 'value'`)
          errors++
        } else {
          console.log(`  PASS ${prefix} — file: "${g.file_pattern}", value: "${g.value.slice(0, 40)}"`)
        }
        break

      case "judge":
        if (!g.question) {
          console.log(`  FAIL ${prefix} — missing 'question'`)
          errors++
        } else {
          console.log(`  PASS ${prefix} — question: "${g.question.slice(0, 60)}..."`)
        }
        break

      case "all":
        if (!g.graders || !Array.isArray(g.graders) || g.graders.length === 0) {
          console.log(`  FAIL ${prefix} — missing or empty 'graders' array`)
          errors++
        } else {
          console.log(`  PASS ${prefix} — ${g.graders.length} sub-graders`)
        }
        break

      default:
        console.log(`  WARN ${prefix} — unknown grader type: ${g.type}`)
        warnings++
    }
  }

  // Summary checks
  console.log("\n  --- Summary ---\n")

  const types = new Set(graders.map((g) => g.type))
  for (const required of ["contains", "not_contains", "judge"]) {
    if (types.has(required)) {
      console.log(`  PASS Has '${required}' grader`)
    } else {
      console.log(`  FAIL Missing required grader type: '${required}'`)
      errors++
    }
  }

  console.log("")
  if (errors > 0) {
    console.log(`  Result: ${errors} error(s), ${warnings} warning(s) — FIX BEFORE RUNNING EVAL\n`)
    process.exit(1)
  } else {
    console.log(`  Result: All ${graders.length} graders valid${warnings > 0 ? `, ${warnings} warning(s)` : ""} — ready to run\n`)
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  console.log("\n  Auth0 Skill Eval Runner\n")

  const dryRun = process.argv.includes("--dry-run")
  const gradeOnly = process.argv.includes("--grade-only")
  const skipBaseline = process.argv.includes("--skip-baseline")
  const sequential = process.argv.includes("--sequential")
  const runsFlag = process.argv.indexOf("--runs")
  const numRuns = runsFlag !== -1 ? parseInt(process.argv[runsFlag + 1], 10) : 1
  if (isNaN(numRuns) || numRuns < 1) {
    console.error("  --runs requires a positive integer")
    process.exit(2)
  }

  // 1. Load eval files
  const skillMdPath = path.join(SKILL_DIR, "SKILL.md")
  const promptMdPath = path.join(EVAL_DIR, "PROMPT.md")
  const gradersPath = path.join(EVAL_DIR, "graders.json")
  const configPath = path.join(EVAL_DIR, "benchmark-config.json")

  for (const [name, p] of [["SKILL.md", skillMdPath], ["PROMPT.md", promptMdPath], ["graders.json", gradersPath], ["benchmark-config.json", configPath]]) {
    if (!fs.existsSync(p)) {
      console.error(`  Missing required file: ${name} (${p})`)
      process.exit(1)
    }
  }

  const skillMd = fs.readFileSync(skillMdPath, "utf-8")
  const promptMd = fs.readFileSync(promptMdPath, "utf-8")
  const graders = JSON.parse(fs.readFileSync(gradersPath, "utf-8"))
  const rawConfig = JSON.parse(fs.readFileSync(configPath, "utf-8"))

  // Normalize config: handle both nested { metadata: { skill_name } } and flat { skill_name } formats
  const config = rawConfig.metadata
    ? rawConfig
    : { metadata: { skill_name: rawConfig.skill_name, framework: rawConfig.framework || "unknown", sdk_type: rawConfig.sdk_type || "unknown" }, ...rawConfig }

  // Dry-run mode: validate graders and exit
  if (dryRun) {
    dryRunGraders(graders)
    return
  }

  console.log(`  Skill:     ${config.metadata.skill_name}`)
  console.log(`  Framework: ${config.metadata.framework}`)
  console.log(`  Graders:   ${graders.length}`)
  console.log(`  Model:     ${MODEL || "(CLI default)"}`)
  console.log(`  Modes:     ${skipBaseline ? "without_skill + with_skill" : "baseline + without_skill + with_skill"}`)
  console.log(`  Execution: ${sequential ? "sequential" : "parallel"}`)
  if (numRuns > 1) console.log(`  Runs:      ${numRuns} per configuration`)

  // 2. Collect all runs
  const allRuns = { without_skill: [], with_skill: [] }
  if (!skipBaseline) allRuns.baseline = []

  if (gradeOnly) {
    // Grade existing workspaces
    const idx = process.argv.indexOf("--grade-only")
    const withoutSkillDir = process.argv[idx + 1]
    const withSkillDir = process.argv[idx + 2]
    if (!withoutSkillDir || !withSkillDir) {
      console.error("\n  Usage: node run-evals.mjs --grade-only <without-skill-dir> <with-skill-dir>")
      process.exit(1)
    }

    console.log("\n--- Grading: Without Skill ---")
    const woResults = await runGraders(graders, path.resolve(withoutSkillDir))
    displayResults("Without Skill", woResults)
    allRuns.without_skill.push({ results: woResults, durationMs: 0, tokens: 0 })

    console.log("\n--- Grading: With Skill ---")
    const wiResults = await runGraders(graders, path.resolve(withSkillDir))
    displayResults("With Skill", wiResults)
    allRuns.with_skill.push({ results: wiResults, durationMs: 0, tokens: 0 })
  } else {
    // Check claude CLI
    if (!(await checkClaudeCli())) {
      console.error("\n  claude CLI not found. Install: https://docs.anthropic.com/en/docs/claude-code")
      process.exit(1)
    }

    // Ask for project
    console.log("")
    const hasProject = await confirm("Do you have an existing project to test against?")

    let projectPath = null
    if (hasProject) {
      const input = await prompt("Enter the path to your project:")
      projectPath = path.resolve(input)
      if (!fs.existsSync(projectPath) || !fs.statSync(projectPath).isDirectory()) {
        console.error(`\n  Project not found or not a directory: ${projectPath}`)
        process.exit(1)
      }
    }

    // Extract task prompt (strip YAML frontmatter)
    const taskPrompt = promptMd.replace(/^---[\s\S]*?---\s*/, "").trim()

    // Create session trace directory
    const tmpBase = path.join(os.tmpdir(), `auth0-eval-${Date.now()}`)
    const tracesDir = path.join(tmpBase, "traces")
    fs.mkdirSync(tracesDir, { recursive: true })

    for (let run = 1; run <= numRuns; run++) {
      const runLabel = numRuns > 1 ? ` (run ${run}/${numRuns})` : ""

      // Create fresh workspaces per run
      const baselineDir = path.join(tmpBase, `run-${run}`, "baseline")
      const withoutSkillDir = path.join(tmpBase, `run-${run}`, "without-skill")
      const withSkillDir = path.join(tmpBase, `run-${run}`, "with-skill")
      fs.mkdirSync(withoutSkillDir, { recursive: true })
      fs.mkdirSync(withSkillDir, { recursive: true })
      if (!skipBaseline) fs.mkdirSync(baselineDir, { recursive: true })

      if (projectPath) {
        const spinner = ora(`Copying project to eval workspaces${runLabel}`).start()
        // Copy to all workspaces in parallel
        const copyTasks = [
          $`cp -r ${projectPath}/. ${withoutSkillDir}/`,
          $`cp -r ${projectPath}/. ${withSkillDir}/`,
        ]
        if (!skipBaseline) copyTasks.push($`cp -r ${projectPath}/. ${baselineDir}/`)
        await Promise.all(copyTasks)
        spinner.succeed(`Project copied${runLabel}`)
      } else if (run === 1) {
        console.log("\n  No project provided. Agents will scaffold from scratch.\n")
      }

      if (sequential) {
        // ---------- Sequential mode (--sequential) ----------
        // Run agents one at a time — use when system resources are limited

        // Baseline
        if (!skipBaseline) {
          console.log(`\n--- Baseline${runLabel} ---\n`)
          const s0 = ora("Running baseline (no tools, no skill)...").start()
          let blRun = { stdout: "", durationMs: 0, tokens: 0 }
          try {
            blRun = await runBaseline(taskPrompt, baselineDir)
            s0.succeed(`Baseline completed — ${(blRun.durationMs / 1000).toFixed(1)}s${blRun.tokens ? `, ${blRun.tokens} tokens` : ""}`)
          } catch (e) {
            s0.fail(`Baseline failed: ${e.message}`)
          }
          fs.writeFileSync(path.join(tracesDir, `run-${run}-baseline.log`), blRun.stdout || "(no output)")

          console.log(`\n--- Grading${runLabel}: Baseline ---`)
          const blResults = await runGraders(graders, baselineDir)
          displayResults(`Baseline${runLabel}`, blResults)
          allRuns.baseline.push({ results: blResults, durationMs: blRun.durationMs, tokens: blRun.tokens })
        }

        // Without skill
        console.log(`\n--- Without Skill${runLabel} ---\n`)
        const s1 = ora("Running agent without skill context...").start()
        let woRun = { stdout: "", durationMs: 0, tokens: 0 }
        try {
          woRun = await runClaude(taskPrompt, withoutSkillDir)
          s1.succeed(`Agent completed (without skill) — ${(woRun.durationMs / 1000).toFixed(1)}s${woRun.tokens ? `, ${woRun.tokens} tokens` : ""}`)
        } catch (e) {
          s1.fail(`Agent failed (without skill): ${e.message}`)
        }
        fs.writeFileSync(path.join(tracesDir, `run-${run}-without-skill.log`), woRun.stdout || "(no output)")

        // With skill
        console.log(`\n--- With Skill${runLabel} ---\n`)
        const s2 = ora("Running agent with skill context...").start()
        let wiRun = { stdout: "", durationMs: 0, tokens: 0 }
        try {
          wiRun = await runClaude(taskPrompt, withSkillDir, skillMd)
          s2.succeed(`Agent completed (with skill) — ${(wiRun.durationMs / 1000).toFixed(1)}s${wiRun.tokens ? `, ${wiRun.tokens} tokens` : ""}`)
        } catch (e) {
          s2.fail(`Agent failed (with skill): ${e.message}`)
        }
        fs.writeFileSync(path.join(tracesDir, `run-${run}-with-skill.log`), wiRun.stdout || "(no output)")

        // Grade all workspaces
        if (!skipBaseline) {
          // Already graded above in sequential mode
        }
        console.log(`\n--- Grading${runLabel}: Without Skill ---`)
        const woResults = await runGraders(graders, withoutSkillDir)
        displayResults(`Without Skill${runLabel}`, woResults)
        allRuns.without_skill.push({ results: woResults, durationMs: woRun.durationMs, tokens: woRun.tokens })

        console.log(`\n--- Grading${runLabel}: With Skill ---`)
        const wiResults = await runGraders(graders, withSkillDir)
        displayResults(`With Skill${runLabel}`, wiResults)
        allRuns.with_skill.push({ results: wiResults, durationMs: wiRun.durationMs, tokens: wiRun.tokens })

      } else {
        // ---------- Parallel mode (default) ----------
        // Run all agents concurrently — each uses an independent workspace
        // Wall-clock time = max(baseline, without_skill, with_skill) instead of sum

        console.log(`\n--- Running agents in parallel${runLabel} ---\n`)

        // Build agent tasks
        const agentTasks = []

        if (!skipBaseline) {
          agentTasks.push({
            label: "baseline",
            run: async () => {
              const spinner = ora("  [baseline] Running (no tools, no skill)...").start()
              try {
                const result = await runBaseline(taskPrompt, baselineDir)
                spinner.succeed(`  [baseline] Completed — ${(result.durationMs / 1000).toFixed(1)}s${result.tokens ? `, ${result.tokens} tokens` : ""}`)
                return result
              } catch (e) {
                spinner.fail(`  [baseline] Failed: ${e.message}`)
                return { stdout: "", durationMs: 0, tokens: 0 }
              }
            },
            workspaceDir: baselineDir,
          })
        }

        agentTasks.push({
          label: "without_skill",
          run: async () => {
            const spinner = ora("  [without_skill] Running agent...").start()
            try {
              const result = await runClaude(taskPrompt, withoutSkillDir)
              spinner.succeed(`  [without_skill] Completed — ${(result.durationMs / 1000).toFixed(1)}s${result.tokens ? `, ${result.tokens} tokens` : ""}`)
              return result
            } catch (e) {
              spinner.fail(`  [without_skill] Failed: ${e.message}`)
              return { stdout: "", durationMs: 0, tokens: 0 }
            }
          },
          workspaceDir: withoutSkillDir,
        })

        agentTasks.push({
          label: "with_skill",
          run: async () => {
            const spinner = ora("  [with_skill] Running agent...").start()
            try {
              const result = await runClaude(taskPrompt, withSkillDir, skillMd)
              spinner.succeed(`  [with_skill] Completed — ${(result.durationMs / 1000).toFixed(1)}s${result.tokens ? `, ${result.tokens} tokens` : ""}`)
              return result
            } catch (e) {
              spinner.fail(`  [with_skill] Failed: ${e.message}`)
              return { stdout: "", durationMs: 0, tokens: 0 }
            }
          },
          workspaceDir: withSkillDir,
        })

        // Run all agents in parallel
        const parallelStart = Date.now()
        const agentResults = await Promise.allSettled(agentTasks.map((t) => t.run()))
        const parallelDuration = ((Date.now() - parallelStart) / 1000).toFixed(1)

        // Extract results
        const resultMap = {}
        agentTasks.forEach((task, i) => {
          const settled = agentResults[i]
          resultMap[task.label] = settled.status === "fulfilled"
            ? settled.value
            : { stdout: "", durationMs: 0, tokens: 0 }
        })

        console.log(`\n  All agents completed in ${parallelDuration}s (wall-clock)\n`)

        // Save session traces
        for (const task of agentTasks) {
          fs.writeFileSync(
            path.join(tracesDir, `run-${run}-${task.label}.log`),
            resultMap[task.label].stdout || "(no output)"
          )
        }

        // Grade all workspaces (grading is fast, run sequentially for clean output)
        if (!skipBaseline) {
          console.log(`--- Grading${runLabel}: Baseline ---`)
          const blResults = await runGraders(graders, baselineDir)
          displayResults(`Baseline${runLabel}`, blResults)
          allRuns.baseline.push({
            results: blResults,
            durationMs: resultMap.baseline.durationMs,
            tokens: resultMap.baseline.tokens,
          })
        }

        console.log(`\n--- Grading${runLabel}: Without Skill ---`)
        const woResults = await runGraders(graders, withoutSkillDir)
        displayResults(`Without Skill${runLabel}`, woResults)
        allRuns.without_skill.push({
          results: woResults,
          durationMs: resultMap.without_skill.durationMs,
          tokens: resultMap.without_skill.tokens,
        })

        console.log(`\n--- Grading${runLabel}: With Skill ---`)
        const wiResults = await runGraders(graders, withSkillDir)
        displayResults(`With Skill${runLabel}`, wiResults)
        allRuns.with_skill.push({
          results: wiResults,
          durationMs: resultMap.with_skill.durationMs,
          tokens: resultMap.with_skill.tokens,
        })
      }
    }

    console.log(`\n  Workspaces: ${tmpBase}`)
    console.log(`  Traces:     ${tracesDir}`)
  }

  // Benchmark
  config.graders_total = graders.length
  const benchmark = computeBenchmark(allRuns, config)

  // Display results
  const rs = benchmark.run_summary
  const d = rs.delta

  console.log("\n--- Benchmark ---\n")

  if (rs.baseline) {
    const bl = rs.baseline
    console.log(`  Baseline:      ${(bl.pass_rate.mean * 100).toFixed(0)}%${bl.runs > 1 ? ` (stddev ${(bl.pass_rate.stddev * 100).toFixed(0)}%)` : ""} — ${bl.time_seconds.mean.toFixed(1)}s${bl.tokens ? `, ${Math.round(bl.tokens.mean)} tokens` : ""}`)
  }
  const wo = rs.without_skill
  const wi = rs.with_skill
  console.log(`  Without Skill: ${(wo.pass_rate.mean * 100).toFixed(0)}%${wo.runs > 1 ? ` (stddev ${(wo.pass_rate.stddev * 100).toFixed(0)}%)` : ""} — ${wo.time_seconds.mean.toFixed(1)}s${wo.tokens ? `, ${Math.round(wo.tokens.mean)} tokens` : ""}`)
  console.log(`  With Skill:    ${(wi.pass_rate.mean * 100).toFixed(0)}%${wi.runs > 1 ? ` (stddev ${(wi.pass_rate.stddev * 100).toFixed(0)}%)` : ""} — ${wi.time_seconds.mean.toFixed(1)}s${wi.tokens ? `, ${Math.round(wi.tokens.mean)} tokens` : ""}`)

  console.log("")
  if (d.baseline_to_without_skill !== undefined) {
    console.log(`  Tool value:    ${d.baseline_to_without_skill >= 0 ? "+" : ""}${(d.baseline_to_without_skill * 100).toFixed(0)}% (baseline → without_skill)`)
  }
  console.log(`  Skill value:   ${d.without_skill_to_with_skill >= 0 ? "+" : ""}${(d.without_skill_to_with_skill * 100).toFixed(0)}% (without_skill → with_skill)`)
  if (d.baseline_to_with_skill !== undefined) {
    console.log(`  Total value:   ${d.baseline_to_with_skill >= 0 ? "+" : ""}${(d.baseline_to_with_skill * 100).toFixed(0)}% (baseline → with_skill)`)
  }
  console.log(`  Time delta:    ${d.time_seconds >= 0 ? "+" : ""}${d.time_seconds.toFixed(1)}s`)
  console.log(`  Assessment:    ${benchmark.assessment}`)

  // Per-grader delta analysis
  const ga = benchmark.grader_analysis
  if (ga.skill_wins.length > 0) {
    console.log(`\n  Skill Wins (fail → pass): ${ga.skill_wins.length}`)
    for (const g of ga.skill_wins) console.log(`    + [${g.type}] ${g.description}`)
  }
  if (ga.always_fail.length > 0) {
    console.log(`\n  Always Fail (both): ${ga.always_fail.length}`)
    for (const g of ga.always_fail) console.log(`    ! [${g.type}] ${g.description}`)
  }
  if (ga.skill_regressions.length > 0) {
    console.log(`\n  Regressions (pass → fail): ${ga.skill_regressions.length}`)
    for (const g of ga.skill_regressions) console.log(`    - [${g.type}] ${g.description}`)
  }

  // Write benchmark.json
  const benchmarkPath = path.join(EVAL_DIR, "benchmark.json")
  fs.writeFileSync(benchmarkPath, JSON.stringify(benchmark, null, 2) + "\n")
  console.log(`\n  Results written to ${benchmarkPath}`)

  // Generate and write feedback.json
  const feedback = generateFeedback(benchmark, graders)
  const feedbackPath = path.join(EVAL_DIR, "feedback.json")
  fs.writeFileSync(feedbackPath, JSON.stringify(feedback, null, 2) + "\n")
  console.log(`  Feedback written to ${feedbackPath}`)

  // Display feedback summary
  if (feedback.suggested_actions.length > 0) {
    console.log("\n  Suggested Actions:")
    for (const a of feedback.suggested_actions) {
      const icon = a.priority === "critical" ? "!!!" : a.priority === "high" ? " ! " : a.priority === "medium" ? " * " : "   "
      console.log(`    ${icon}[${a.priority}] ${a.action}`)
    }
  }
  console.log("")
}

main().catch((e) => {
  console.error(`\n  Eval runner failed: ${e.message}\n`)
  process.exit(1)
})
