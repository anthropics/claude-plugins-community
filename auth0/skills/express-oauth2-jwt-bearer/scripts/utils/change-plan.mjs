export const ChangeAction = {
  CREATE: "create",
  UPDATE: "update",
  SKIP: "skip",
}

export function createChangeItem(action, details = {}) {
  return {
    action,
    ...details,
  }
}
