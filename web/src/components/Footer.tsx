import { Logo } from './Logo'

export function Footer() {
  return (
    <footer>
      <div className="wrap foot">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <Logo size={30} animated={false} />
          <div>
            <div className="brand-name">Connection<span>Limit</span></div>
            <p>Sehen, wer Datenvolumen verbraucht — und es abdrehen.</p>
          </div>
        </div>
        <p>Gebaut für Hotspot, Roaming und Hotel-Tarif.</p>
      </div>
    </footer>
  )
}
