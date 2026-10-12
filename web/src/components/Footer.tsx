import { Logo } from './Logo'
import { useLang } from '../i18n'

export function Footer() {
  const { t } = useLang()
  return (
    <footer>
      <div className="wrap foot">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <Logo size={30} animated={false} />
          <div>
            <div className="brand-name">Connection<span>Limit</span></div>
            <p>{t.footer.tagline}</p>
          </div>
        </div>
        <p>{t.footer.made}</p>
      </div>
    </footer>
  )
}
