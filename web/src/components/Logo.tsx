/// Die Bildmarke, identisch zum App-Symbol: drei Balken (Verbrauch) und eine
/// harte Linie darüber (die Grenze). Der dritte stößt an — was darüber läge,
/// bleibt als Umriss stehen.
///
/// Beim Laden wird die Aussage einmal vorgeführt: Die Balken wachsen, dann
/// fährt die Grenze ein und kappt den größten. Danach steht das Bild still.
export function Logo({ size = 38, animated = true }: { size?: number; animated?: boolean }) {
  const cls = animated ? 'logo animated' : 'logo'
  return (
    <svg className={cls} width={size} height={size} viewBox="0 0 100 100"
         role="img" aria-label="ConnectionLimit">
      <defs>
        <linearGradient id="cl-plate" x1="0" y1="1" x2="0.7" y2="0">
          <stop offset="0%" stopColor="#16263F" />
          <stop offset="55%" stopColor="#0B1524" />
          <stop offset="100%" stopColor="#050B14" />
        </linearGradient>
        <radialGradient id="cl-glow" cx="0.5" cy="0.66" r="0.55">
          <stop offset="0%" stopColor="#3DDC97" stopOpacity="0.22" />
          <stop offset="100%" stopColor="#3DDC97" stopOpacity="0" />
        </radialGradient>
      </defs>

      <rect width="100" height="100" rx="22.4" fill="url(#cl-plate)" />
      <rect width="100" height="100" rx="22.4" fill="url(#cl-glow)" />

      {/* Der Teil oberhalb der Grenze: sichtbar, aber nicht mehr gezählt. */}
      <rect className="ghost" x="60.2" y="17" width="11.7" height="46" rx="5.85"
            fill="none" stroke="#FF5F56" strokeOpacity="0.3" strokeWidth="1.1" />

      <g className="bars">
        <rect className="bar b1" x="28.1" y="55.4" width="11.7" height="21.6" rx="5.85" fill="#3DDC97" />
        <rect className="bar b2" x="44.1" y="43.5" width="11.7" height="33.5" rx="5.85" fill="#FFB020" />
        <rect className="bar b3" x="60.2" y="38.5" width="11.7" height="38.5" rx="5.85" fill="#FF5F56" />
      </g>

      <g className="limit">
        <rect x="20.3" y="34.2" width="59.4" height="2.8" rx="1.4" fill="#F7FAFC" />
        <circle cx="20.3" cy="35.6" r="3.4" fill="#F7FAFC" />
        <circle cx="20.3" cy="35.6" r="1.5" fill="#0B1524" />
      </g>
    </svg>
  )
}

export function Wordmark() {
  return (
    <a className="brand" href="#top">
      <Logo size={34} />
      <span className="brand-name">Connection<span>Limit</span></span>
    </a>
  )
}
