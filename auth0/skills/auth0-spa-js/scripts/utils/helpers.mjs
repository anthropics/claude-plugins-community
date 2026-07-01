import readline from "node:readline/promises"
import { select } from "@inquirer/prompts"

export async function confirmWithUser(message) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  })

  const answer = await rl.question(`${message} (y/N): `)
  rl.close()

  return answer.toLowerCase() === "y" || answer.toLowerCase() === "yes"
}

export async function getInputFromUser(message) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  })

  const answer = await rl.question(`${message} `)
  rl.close()

  return answer.trim()
}

export async function selectOptionFromList(message, options) {
  const answer = await select({ message, choices: options })
  return answer
}
