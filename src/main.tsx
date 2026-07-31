import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { App } from './App'
import { AuthProvider } from './auth/AuthProvider'
import { I18nProvider } from './i18n'
import './styles.css'
import './f02.css'
import './f07.css'
import './f08.css'
import './f09.css'

const queryClient = new QueryClient({defaultOptions:{queries:{staleTime:30_000,retry:1}}})

createRoot(document.getElementById('root')!).render(
  <StrictMode><QueryClientProvider client={queryClient}><BrowserRouter><AuthProvider><I18nProvider><App/></I18nProvider></AuthProvider></BrowserRouter></QueryClientProvider></StrictMode>,
)

if('serviceWorker' in navigator)window.addEventListener('load',()=>navigator.serviceWorker.register('/sw.js'))
