import ora from "ora"

import { auth0ApiCall } from "./auth0-api.mjs"
import { ChangeAction } from "./change-plan.mjs"
import { checkSpaClientChanges } from "./clients.mjs"
import { checkDatabaseConnectionChanges } from "./connections.mjs"

export async function discoverExistingConnections() {
  const spinner = ora("Discovering existing connections").start()
  try {
    const connections = (await auth0ApiCall("get", "connections")) || []
    spinner.succeed("Discovered existing connections")
    return connections
  } catch (e) {
    const msg = e.message || String(e)
    if (msg.includes("404") || msg.includes("Not Found")) {
      spinner.succeed("No existing connections found")
      return []
    }
    spinner.fail("Failed to discover connections")
    throw e
  }
}

export function buildChangePlan(connections, domain, spaConfig) {
  const clientPlan = checkSpaClientChanges(domain, spaConfig)
  const connectionPlan = checkDatabaseConnectionChanges(connections, "TO_BE_CREATED")
  return { client: clientPlan, connection: connectionPlan }
}

export function displayChangePlan(plan) {
  console.log("\n  Change Plan:\n")

  const items = [
    { name: "SPA Client", ...plan.client },
    { name: "Database Connection", ...plan.connection },
  ]

  for (const item of items) {
    const icon =
      item.action === ChangeAction.CREATE ? "+" :
      item.action === ChangeAction.UPDATE ? "~" : "="
    const label =
      item.action === ChangeAction.CREATE ? "CREATE" :
      item.action === ChangeAction.UPDATE ? "UPDATE" : "SKIP  "

    let detail = ""
    if (item.summary) detail = ` (${item.summary})`
    else if (item.callbackUrl) detail = ` (callback: ${item.callbackUrl})`

    console.log(`  ${icon} [${label}] ${item.name || item.resource}${detail}`)
  }

  console.log("")
}
