import ora from "ora"

import { auth0ApiCall } from "./auth0-api.mjs"
import { ChangeAction, createChangeItem } from "./change-plan.mjs"

export const DEFAULT_CONNECTION_NAME = "Username-Password-Authentication"

export function checkDatabaseConnectionChanges(existingConnections, clientId) {
  const existing = existingConnections.find((c) => c.name === DEFAULT_CONNECTION_NAME)

  if (!existing) {
    return createChangeItem(ChangeAction.CREATE, {
      resource: "Database Connection",
      name: DEFAULT_CONNECTION_NAME,
      enabledClients: [clientId],
    })
  }

  const enabledClients = existing.enabled_clients || []
  if (!enabledClients.includes(clientId)) {
    return createChangeItem(ChangeAction.UPDATE, {
      resource: "Database Connection",
      name: DEFAULT_CONNECTION_NAME,
      existing,
      summary: "Enable client on connection",
    })
  }

  return createChangeItem(ChangeAction.SKIP, {
    resource: "Database Connection",
    name: DEFAULT_CONNECTION_NAME,
    existing,
  })
}

export async function applyDatabaseConnectionChanges(changePlan, clientId) {
  if (changePlan.action === ChangeAction.SKIP) {
    const spinner = ora(`Database Connection is up to date: ${changePlan.name}`).start()
    spinner.succeed()
    return changePlan.existing
  }

  if (changePlan.action === ChangeAction.CREATE) {
    const spinner = ora(`Creating Database Connection: ${DEFAULT_CONNECTION_NAME}`).start()
    try {
      const connectionData = {
        strategy: "auth0",
        name: DEFAULT_CONNECTION_NAME,
        enabled_clients: [clientId],
      }
      const connection = await auth0ApiCall("post", "connections", connectionData)
      spinner.succeed(`Created Database Connection: ${DEFAULT_CONNECTION_NAME}`)
      return connection
    } catch (e) {
      spinner.fail("Failed to create Database Connection")
      throw e
    }
  }

  if (changePlan.action === ChangeAction.UPDATE) {
    const spinner = ora(`Updating Database Connection: ${DEFAULT_CONNECTION_NAME}`).start()
    try {
      const existing = changePlan.existing
      const updatedClients = [...(existing.enabled_clients || []), clientId]
      await auth0ApiCall("patch", `connections/${existing.id}`, {
        enabled_clients: updatedClients,
      })
      spinner.succeed(`Updated ${DEFAULT_CONNECTION_NAME}: enabled client ${clientId}`)
      return { ...existing, enabled_clients: updatedClients }
    } catch (e) {
      spinner.fail("Failed to update Database Connection")
      throw e
    }
  }
}
