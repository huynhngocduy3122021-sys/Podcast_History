import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { AuthProvider } from './auth'
import { FeedbackProvider } from './components/feedback'
import { App } from './app'
import './styles.css'
import { session } from './lib/client'
import { initializeTheme } from './lib/theme'

initializeTheme()

const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false, staleTime: 30000, refetchOnWindowFocus: false }, mutations: { retry: false } } })
let identity = ''
session.subscribe(() => {
  const user = session.getUser()
  const nextIdentity = user ? `${user.id}:${user.role}` : ''
  if (identity !== nextIdentity) queryClient.clear()
  identity = nextIdentity
})
createRoot(document.getElementById('root')!).render(<StrictMode><QueryClientProvider client={queryClient}><BrowserRouter><FeedbackProvider><AuthProvider><App /></AuthProvider></FeedbackProvider></BrowserRouter></QueryClientProvider></StrictMode>)
