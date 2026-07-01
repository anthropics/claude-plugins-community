import { $ } from "execa"

/**
 * Make a generic API call using auth0 CLI.
 */
export async function auth0ApiCall(method, endpoint, data = null) {
  const args = ["api", method, endpoint, "--no-input"]

  if (data) {
    args.push("--data", JSON.stringify(data))
  }

  try {
    const { stdout } = await $({ timeout: 30000 })`auth0 ${args}`
    return stdout ? JSON.parse(stdout) : null
  } catch (e) {
    if (e.timedOut) {
      console.warn(`Warning: API call timed out: auth0 api ${method} ${endpoint}`)
    } else {
      console.warn(`Warning: API call failed: ${e.message}`)
    }
    throw e
  }
}
