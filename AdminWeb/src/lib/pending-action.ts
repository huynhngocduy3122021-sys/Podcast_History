// The lock is synchronous: a second click before React renders cannot submit again.
export function pendingAction() {
  let running = false
  return async (action: () => Promise<void>): Promise<boolean> => {
    if (running) return false
    running = true
    try { await action(); return true }
    finally { running = false }
  }
}
