import { Logo } from './Logo'
import { LEGAL_PARTS } from './Legal'
import { COMPANY } from '../lib/company'
import { statsEnabled } from '../lib/stats'
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
      <div className="wrap foot foot-legal">
        <p>
          {t.footer.project} <a href={t.footer.dsolUrl}>DSOL</a>
          <span className="foot-sep" aria-hidden>·</span>
          {t.footer.madeWith} <a href={COMPANY.founder}>Marco Schweitzer</a>
        </p>
        <nav className="foot-links" aria-label={t.legal.title}>
          {LEGAL_PARTS.map((id) => (
            <a key={id} href={`#${id}`}>{t.legal.links[id]}</a>
          ))}
          {statsEnabled && <a href="#statistik">{t.stats.settings}</a>}
        </nav>
      </div>
    </footer>
  )
}
