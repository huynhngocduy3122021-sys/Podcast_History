export type Theme = 'light' | 'dark'
const storageKey = 'vietcast.admin.theme'

export function applyTheme(theme: Theme) {
  document.documentElement.dataset.theme = theme
  try { localStorage.setItem(storageKey, theme) } catch { /* Theme still works without storage. */ }
}

export function initializeTheme() {
  let saved: string | null = null
  try { saved = localStorage.getItem(storageKey) } catch { /* Use system preference. */ }
  const theme = saved === 'light' || saved === 'dark' ? saved : window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
  applyTheme(theme)
}
