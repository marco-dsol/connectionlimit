import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App'
import { LangProvider } from './i18n'
import './styles.css'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <LangProvider>
      <App />
    </LangProvider>
  </StrictMode>,
)

// Ein Link wie `…/#terminal` springt sonst nirgendwohin: Der Browser sucht
// den Abschnitt, bevor React ihn gezeichnet hat. Also nach dem ersten
// Zeichnen selbst hinspringen.
if (window.location.hash) {
  requestAnimationFrame(() => {
    try {
      document.querySelector(decodeURIComponent(window.location.hash))?.scrollIntoView()
    } catch {
      /* kein gültiger Selektor — dann eben oben bleiben */
    }
  })
}
