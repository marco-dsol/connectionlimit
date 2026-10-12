import { useReveal } from '../hooks/useReveal'
import { useLang } from '../i18n'

/// Der wichtigste Abschnitt dieser Seite.
///
/// Ein Werkzeug, das verspricht, Apps das Netz zu entziehen, muss sagen, was
/// es dafür wirklich tut — sonst hält jemand für gesperrt, was in Wahrheit
/// weiterläuft. Diese Seite verkauft die Grenzen mit, nicht nur die Stärken.
export function Honest() {
  const { t } = useLang()
  const h = t.honest
  const head = useReveal<HTMLDivElement>()
  const grid = useReveal<HTMLDivElement>(80)
  const table = useReveal<HTMLDivElement>(160)

  return (
    <section id="grenzen">
      <div className="wrap">
        <div className="section-head reveal" ref={head}>
          <span className="eyebrow">{h.eyebrow}</span>
          <h2>{h.title}</h2>
          <p className="lead">{h.lead}</p>
        </div>

        <div className="honest-grid reveal" ref={grid}>
          <div className="honest can">
            <h3><span aria-hidden>✓</span> {h.canTitle}</h3>
            <ul>
              {h.can.map((item, index) => <li key={index}><span>{item}</span></li>)}
            </ul>
          </div>

          <div className="honest cannot">
            <h3><span aria-hidden>✗</span> {h.cannotTitle}</h3>
            <ul>
              {h.cannot.map((item, index) => <li key={index}><span>{item}</span></li>)}
            </ul>
          </div>
        </div>

        <div className="card reveal" ref={table} style={{ marginTop: 18, padding: 24 }}>
          <h3 style={{ marginBottom: 4 }}>{h.leversTitle}</h3>
          <p style={{ fontSize: '0.86rem', color: 'var(--muted)', marginBottom: 10 }}>
            {h.leversLead}
          </p>
          <div className="table-scroll">
            <table className="lever-table">
              <thead>
                <tr><th>{h.head.lever}</th><th>{h.head.effect}</th><th>{h.head.rights}</th></tr>
              </thead>
              <tbody>
                {h.levers.map((lever) => (
                  <tr key={lever.name}>
                    <td>{lever.name}</td>
                    <td>{lever.effect}</td>
                    <td className={`accent-${lever.tone}`}>{lever.rights}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </section>
  )
}
