import { useState } from 'react'
import { Moon, Sun } from 'lucide-react'
import { applyTheme } from '../lib/theme'
import type { Theme } from '../lib/theme'
import { Button } from './ui/button'

export function ThemeToggle({ collapsed }: { collapsed: boolean }) {
  const [theme, setTheme] = useState<Theme>(() => document.documentElement.dataset.theme === 'dark' ? 'dark' : 'light')
  return <div role="group" aria-label="Giao diện sáng hoặc tối" className={`flex w-full gap-1 rounded-xl border border-border bg-muted p-1 ${collapsed ? 'lg:flex-col' : ''}`}>
    {([{ value: 'light', label: 'Nền sáng', Icon: Sun }, { value: 'dark', label: 'Nền tối', Icon: Moon }] as const).map(({ value, label, Icon }) => <Button key={value} variant="ghost" className={`flex-1 px-2 ${theme === value ? 'bg-surface text-primary shadow-sm hover:bg-surface hover:text-primary' : ''}`} aria-label={label} title={label} aria-pressed={theme === value} onClick={() => {
      applyTheme(value)
      setTheme(value)
    }}><Icon className="size-5" aria-hidden="true" /></Button>)}
  </div>
}
