export type StompFrame = { command: string; headers: Record<string, string>; body: string }

export function stompFrame(command: string, headers: Record<string, string>, body = '') {
  const lines = [command, ...Object.entries(headers).map(([key, value]) => `${key}:${value}`), '', body]
  return `${lines.join('\n')}\0`
}

export function parseStompFrame(value: string): StompFrame | null {
  const clean = value.replace(/^\n+/, '')
  const separator = clean.indexOf('\n\n')
  if (separator < 0) return null
  const headerLines = clean.slice(0, separator).split('\n')
  const command = headerLines.shift() || ''
  const headers: Record<string, string> = {}
  for (const line of headerLines) {
    const index = line.indexOf(':')
    if (index > 0) headers[line.slice(0, index)] = line.slice(index + 1)
  }
  return { command, headers, body: clean.slice(separator + 2).replace(/\0$/, '') }
}
