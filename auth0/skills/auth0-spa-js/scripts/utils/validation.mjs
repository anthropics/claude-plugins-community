import fs from "node:fs"
import path from "node:path"

import { $ } from "execa"
import ora from "ora"

// ---------------------------------------------------------------------------
// Shared preflight checks
// ---------------------------------------------------------------------------

export function checkNodeVersion() {
  const [major] = process.versions.node.split(".").map(Number)
  if (major < 20) {
    console.error(`❌ Node.js 20+ required (found ${process.version})`)
    process.exit(1)
  }
}

export async function checkAuth0CLI() {
  const spinner = ora("Checking Auth0 CLI").start()
  try {
    await $`auth0 --version --no-input`
    spinner.succeed("Auth0 CLI found")
  } catch {
    spinner.fail("Auth0 CLI not found")
    console.error("\n  Install Auth0 CLI: https://github.com/auth0/auth0-cli#installation")
    console.error("  macOS:   brew install auth0/auth0-cli/auth0")
    console.error("  Linux:   curl -sSfL https://raw.githubusercontent.com/auth0/auth0-cli/main/install.sh | sh")
    console.error("  Windows: scoop install auth0\n")
    process.exit(1)
  }
}

export async function getActiveTenant() {
  const spinner = ora("Detecting active Auth0 tenant").start()
  try {
    const { stdout } = await $`auth0 tenants list --csv --no-input`
    const lines = stdout.trim().split("\n").filter(Boolean)
    // CSV format: domain,name,client_id — find the active one (marked with *)
    // Fallback: use the first tenant
    let domain = null
    for (const line of lines) {
      if (line.startsWith("*") || line.includes(",")) {
        domain = line.replace(/^\*\s*/, "").split(",")[0].trim()
        break
      }
    }
    if (!domain) {
      throw new Error("No active tenant found")
    }
    spinner.succeed(`Active tenant: ${domain}`)
    return domain
  } catch (e) {
    spinner.fail("Failed to detect active tenant")
    console.error("\n  Run 'auth0 login' to authenticate with your Auth0 tenant\n")
    process.exit(1)
  }
}

// ---------------------------------------------------------------------------
// SPA project validator
// ---------------------------------------------------------------------------

export function validateSpaProject(projectPath) {
  const spinner = ora("Validating SPA project").start()

  const pkgPath = path.join(projectPath, "package.json")
  if (!fs.existsSync(pkgPath)) {
    spinner.fail(`No package.json found in ${projectPath}`)
    console.error("\n  Please provide the path to your SPA project directory\n")
    process.exit(1)
  }

  let pkg
  try {
    pkg = JSON.parse(fs.readFileSync(pkgPath, "utf-8"))
  } catch (e) {
    spinner.fail("Failed to parse package.json")
    process.exit(1)
  }

  const deps = { ...pkg.dependencies, ...pkg.devDependencies }

  // Detect framework and default dev server port
  let framework = "unknown"
  let port = 5173 // default Vite port

  if (deps["react-scripts"]) {
    framework = "react-cra"
    port = 3000
  } else if (deps["vite"] && deps["svelte"]) {
    framework = "svelte"
    port = 5173
  } else if (deps["vite"] && (deps["solid-js"] || deps["solid"])) {
    framework = "solid"
    port = 5173
  } else if (deps["vite"]) {
    framework = "vite"
    port = 5173
  } else if (deps["@angular/core"]) {
    framework = "angular"
    port = 4200
  } else if (deps["vue"]) {
    framework = "vue"
    port = 5173
  } else if (deps["react"]) {
    framework = "react"
    port = 3000
  }

  spinner.succeed(`SPA project: ${pkg.name || "unnamed"} (${framework}, port ${port})`)
  return { packageName: pkg.name || "app", framework, port }
}
