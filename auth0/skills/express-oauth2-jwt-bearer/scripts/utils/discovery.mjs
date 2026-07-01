import ora from "ora"
import { auth0ApiCall } from "./auth0-api.mjs"
import { ChangeAction } from "./change-plan.mjs"
import { checkApiChanges } from "./apis.mjs"

export async function discoverExistingApis() {
  const spinner = ora("Discovering existing APIs").start()
  try {
    const apis = (await auth0ApiCall("get", "resource-servers")) || []
    spinner.succeed("Discovered existing APIs")
    return apis
  } catch (e) {
    const msg = e.message || String(e)
    if (msg.includes("404") || msg.includes("Not Found")) {
      spinner.succeed("No existing APIs found")
      return []
    }
    spinner.fail("Failed to discover APIs")
    throw e
  }
}

export function buildChangePlan(apis, domain, apiConfig) {
  const apiPlan = checkApiChanges(domain, apiConfig)
  return { api: apiPlan }
}

export function displayChangePlan(plan) {
  console.log("\n  Change Plan:\n")

  const items = [{ name: "API", ...plan.api }]

  for (const item of items) {
    const icon =
      item.action === ChangeAction.CREATE ? "+" :
      item.action === ChangeAction.UPDATE ? "~" : "="
    const label =
      item.action === ChangeAction.CREATE ? "CREATE" :
      item.action === ChangeAction.UPDATE ? "UPDATE" : "SKIP  "

    let detail = ""
    if (item.identifier) detail = ` (identifier: ${item.identifier})`

    console.log(`  ${icon} [${label}] ${item.name || item.resource}${detail}`)
  }

  console.log("")
}
