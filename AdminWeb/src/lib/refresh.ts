// Kept independent of transport so concurrency and rotation can be tested directly.
export function singleFlight<T>(operation: () => Promise<T>) {
  let pending: Promise<T> | undefined
  return (): Promise<T> => {
    if (!pending) {
      pending = Promise.resolve().then(operation).finally(() => { pending = undefined })
    }
    return pending
  }
}

// A late 401 for an older token must use the rotated token, not rotate it again.
export function needsRefresh(sentToken: string | undefined, currentToken: string | undefined) {
  return !currentToken || sentToken === currentToken
}
