import { $ } from "execa"
import ora from "ora"

import { ChangeAction, createChangeItem } from "./change-plan.mjs"

export function checkSpaClientChanges(domain, spaConfig) {
  const { packageName, port } = spaConfig
  const callbackUrl = `http://localhost:${port}`

  return createChangeItem(ChangeAction.CREATE, {
    resource: "SPA Client",
    name: `${packageName}-spa`,
    callbackUrl,
  })
}

export async function applySpaClientChanges(changePlan) {
  const spinner = ora(`Creating SPA Client: ${changePlan.name}`).start()
  try {
    const createArgs = [
      "apps", "create",
      "--name", changePlan.name,
      "--type", "spa",
      "--auth-method", "none",
      "--callbacks", changePlan.callbackUrl,
      "--logout-urls", changePlan.callbackUrl,
      "--origins", changePlan.callbackUrl,
      "--web-origins", changePlan.callbackUrl,
      "--json",
      "--no-input",
    ]
    const { stdout } = await $({ timeout: 30000 })`auth0 ${createArgs}`
    const client = JSON.parse(stdout)
    spinner.succeed(`Created SPA Client: ${changePlan.name} (${client.client_id})`)
    return client
  } catch (e) {
    spinner.fail("Failed to create SPA Client")
    throw e
  }
}
