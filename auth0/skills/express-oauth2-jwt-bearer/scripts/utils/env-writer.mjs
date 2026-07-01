import fs from "node:fs"
import ora from "ora"

export async function writeEnvFile(config, envFilePath) {
  const spinner = ora("Writing .env").start()

  try {
    let content = ""
    if (fs.existsSync(envFilePath)) {
      content = fs.readFileSync(envFilePath, "utf-8")
    }

    for (const [key, value] of Object.entries(config)) {
      const pattern = new RegExp(`^${key}=.*$`, "m")
      if (pattern.test(content)) {
        content = content.replace(pattern, `${key}=${value}`)
      } else {
        content += (content && !content.endsWith("\n") ? "\n" : "") + `${key}=${value}\n`
      }
    }

    fs.writeFileSync(envFilePath, content)
    spinner.succeed(`Updated ${envFilePath}`)
  } catch (e) {
    spinner.fail("Failed to write .env")
    throw e
  }
}
