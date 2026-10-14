export function apiHeaders(baseURL: string): Record<string, string> {
  const host = new URL(baseURL).hostname
  const ngrok = /\.(ngrok-free\.dev|ngrok-free\.app|ngrok\.app|ngrok\.io)$/.test(host)
  return ngrok ? { Accept: 'application/json', 'ngrok-skip-browser-warning': 'true' } : { Accept: 'application/json' }
}
