#!/usr/bin/env node
import path from "node:path"

import {
  checkNodeVersion,
  checkAuth0CLI,
  getActiveTenant,
  validateApiProject,
} from "./utils/validation.mjs"
import {
  discoverExistingApis,
  buildChangePlan,
  displayChangePlan,
} from "./utils/discovery.mjs"
import { applyApiChanges } from "./utils/apis.mjs"
import { writeEnvFile } from "./utils/env-writer.mjs"
import { confirmWithUser } from "./utils/helpers.mjs"

async function main() {
  console.log("\n  Auth0 Express API Bootstrap\n")

  const projectPath = path.resolve(process.argv[2] || process.cwd())

  // Pre-flight
  checkNodeVersion()
  await checkAuth0CLI()
  const domain = await getActiveTenant()

  // Validate project
  const config = validateApiProject(projectPath)

  // Discover + plan
  const apis = await discoverExistingApis()
  const plan = buildChangePlan(apis, domain, config)
  displayChangePlan(plan)

  // Confirm
  const confirmed = await confirmWithUser("Apply these changes?")
  if (!confirmed) {
    console.log("\n  Aborted by user.\n")
    process.exit(0)
  }

  // Execute
  console.log("")
  const api = await applyApiChanges(plan.api)

  const envPath = path.join(projectPath, ".env")
  await writeEnvFile(
    {
      // SDK-native env vars: express-oauth2-jwt-bearer auto-detects these.
      // ISSUER_BASE_URL must include the https:// scheme.
      ISSUER_BASE_URL: `https://${domain}`,
      AUDIENCE: api.identifier,
    },
    envPath
  )

  // Summary
  console.log("\n  Auth0 Express API Setup Complete\n")
  console.log(`  Domain:    ${domain}`)
  console.log(`  Audience:  ${api.identifier}`)
  console.log("")
  console.log("  Next steps:")
  console.log("    1. Install SDK: npm install express-oauth2-jwt-bearer dotenv cors")
  console.log("    2. Add middleware (see references/integration.md)")
  console.log("    3. Test with: curl http://localhost:3000/api/private")
  console.log("")
}

main().catch((e) => {
  console.error(`\n  Bootstrap failed: ${e.message}\n`)
  process.exit(1)
})
