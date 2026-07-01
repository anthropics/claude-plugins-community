import { $ } from "execa"
import fs from "node:fs"
import path from "node:path"
import ora from "ora"

export function checkNodeVersion() {
  const [major] = process.versions.node.split(".").map(Number)
  if (major < 20) {
    console.error(`Node.js 20 or later is required (current: ${process.version})`)
    process.exit(1)
  }
}

export async function checkAuth0CLI() {
  const spinner = ora("Checking Auth0 CLI").start()
  try {
    const versionArgs = ["--version", "--no-input"]
    const { stdout } = await $({ timeout: 10000 })`auth0 ${versionArgs}`
    spinner.succeed(`Auth0 CLI found: ${stdout.trim()}`)
  } catch {
    spinner.fail("Auth0 CLI is not installed")
    console.error(
      "\nInstall it:\n" +
      "  macOS:  brew install auth0/auth0-cli/auth0\n" +
      "  Linux:  curl -sSfL https://raw.githubusercontent.com/auth0/auth0-cli/main/install.sh | sh\n" +
      "  More:   https://github.com/auth0/auth0-cli\n"
    )
    process.exit(1)
  }
}

export async function getActiveTenant() {
  const spinner = ora("Detecting active tenant").start()
  try {
    const tenantsArgs = ["tenants", "list", "--csv", "--no-input"]
    const { stdout } = await $({ timeout: 10000 })`auth0 ${tenantsArgs}`

    const activeLine = stdout
      .split("\n")
      .slice(1)
      .find((line) => line.includes("\u2192"))

    const domain = activeLine?.split(",")[1]?.trim()
    if (!domain) {
      spinner.fail("No active tenant. Run `auth0 login` then re-run this script.")
      process.exit(1)
    }

    spinner.succeed(`Active tenant: ${domain}`)
    return domain
  } catch {
    spinner.fail("Not logged in. Run `auth0 login` then re-run this script.")
    process.exit(1)
  }
}

export function validateApiProject(projectPath) {
  const spinner = ora("Validating API project").start()

  // Detect framework from project files
  const detectors = [
    { file: "*.csproj", framework: "dotnet", port: 5000 },
    { file: "composer.json", framework: "laravel", port: 8000 },
    { file: "Gemfile", framework: "rails", port: 3000 },
    { file: "go.mod", framework: "go", port: 3000 },
    { file: "requirements.txt", framework: "python", port: 8000 },
    { file: "pyproject.toml", framework: "python", port: 8000 },
    { file: "package.json", framework: "node", port: 3000 },
  ]

  let framework = null
  let port = 3000
  for (const d of detectors) {
    const pattern = d.file.includes("*")
      ? fs.readdirSync(projectPath).some((f) => f.endsWith(d.file.replace("*", "")))
      : fs.existsSync(path.join(projectPath, d.file))
    if (pattern) {
      framework = d.framework
      port = d.port
      break
    }
  }

  if (!framework) {
    spinner.fail(`Could not detect project framework in ${projectPath}`)
    process.exit(1)
  }

  spinner.succeed(`API project: ${framework} (port ${port})`)
  return { framework, port }
}
