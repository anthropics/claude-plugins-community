#!/usr/bin/env node

import path from "node:path"

import {
  checkNodeVersion,
  checkAuth0CLI,
  getActiveTenant,
  validateSpaProject,
} from "./utils/validation.mjs"
import {
  discoverExistingConnections,
  buildChangePlan,
  displayChangePlan,
} from "./utils/discovery.mjs"
import { applySpaClientChanges } from "./utils/clients.mjs"
import { applyDatabaseConnectionChanges, checkDatabaseConnectionChanges } from "./utils/connections.mjs"
import { writeEnvFile } from "./utils/env-writer.mjs"
import { confirmWithUser } from "./utils/helpers.mjs"

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  console.log("\n🚀 Auth0 SPA JS Bootstrap\n")

  // 1. Parse args — optional project path (defaults to cwd)
  const projectPath = path.resolve(process.argv[2] || process.cwd())

  // 2. Pre-flight checks
  checkNodeVersion()
  await checkAuth0CLI()

  // 3. Auto-detect tenant
  const domain = await getActiveTenant()

  // 4. Validate SPA project
  const spaConfig = validateSpaProject(projectPath)

  // 5. Discover existing connections
  const connections = await discoverExistingConnections()

  // 6. Build change plan
  const plan = buildChangePlan(connections, domain, spaConfig)

  // 7. Display plan
  displayChangePlan(plan)

  // 8. Confirm with user
  const confirmed = await confirmWithUser("Apply these changes?")
  if (!confirmed) {
    console.log("\n❌ Aborted by user.\n")
    process.exit(0)
  }

  // 9. Create SPA app
  console.log("")
  const client = await applySpaClientChanges(plan.client)

  // 10. Set up database connection with the real client_id
  plan.connection = checkDatabaseConnectionChanges(connections, client.client_id)
  await applyDatabaseConnectionChanges(plan.connection, client.client_id)

  // 11. Write .env file
  const envFilePath = path.join(projectPath, ".env")
  const envVars = getEnvVars(spaConfig.framework, domain, client.client_id)
  await writeEnvFile(envVars, envFilePath)

  // 12. Summary
  console.log("\n✅ Auth0 SPA JS Setup Complete\n")
  console.log(`  Domain:      ${domain}`)
  console.log(`  Client ID:   ${client.client_id}`)
  console.log(`  Framework:   ${spaConfig.framework}`)
  console.log(`  Port:        ${spaConfig.port}`)
  console.log(`  Callback:    http://localhost:${spaConfig.port}`)
  console.log("")
  console.log("  Remaining manual steps:")
  console.log("  1. In Auth0 Dashboard → Application → Settings, verify:")
  console.log(`     Allowed Callback URLs:  http://localhost:${spaConfig.port}`)
  console.log(`     Allowed Logout URLs:    http://localhost:${spaConfig.port}`)
  console.log(`     Allowed Web Origins:    http://localhost:${spaConfig.port}`)
  console.log("  2. Restart your dev server to pick up the new .env values")
  console.log("  3. Initialize createAuth0Client() with your env vars")
  console.log("")
}

/**
 * Determine the correct env var prefix based on detected framework.
 */
function getEnvVars(framework, domain, clientId) {
  const prefix = framework === "react-cra" ? "REACT_APP_AUTH0" : "VITE_AUTH0"
  return {
    [`${prefix}_DOMAIN`]: domain,
    [`${prefix}_CLIENT_ID`]: clientId,
  }
}

main().catch((e) => {
  console.error(`\n❌ Bootstrap failed: ${e.message}\n`)
  process.exit(1)
})
