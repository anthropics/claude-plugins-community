import { $ } from "execa"
import ora from "ora"
import { ChangeAction, createChangeItem } from "./change-plan.mjs"

export function checkApiChanges(domain, apiConfig) {
  const { framework } = apiConfig
  const identifier = `https://${domain}/api/${framework}`

  return createChangeItem(ChangeAction.CREATE, {
    resource: "API",
    name: `${framework}-api`,
    identifier,
  })
}

export async function applyApiChanges(changePlan) {
  const spinner = ora(`Creating API: ${changePlan.name}`).start()
  try {
    const createArgs = [
      "apis", "create",
      "--name", changePlan.name,
      "--identifier", changePlan.identifier,
      "--signing-alg", "RS256",
      "--json",
      "--no-input",
    ]
    const { stdout } = await $({ timeout: 30000 })`auth0 ${createArgs}`
    const api = JSON.parse(stdout)
    spinner.succeed(`Created API: ${changePlan.name} (${api.identifier})`)
    return api
  } catch (e) {
    spinner.fail("Failed to create API")
    throw e
  }
}
