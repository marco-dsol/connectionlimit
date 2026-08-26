import { useReveal } from '../hooks/useReveal'

/// Der wichtigste Abschnitt dieser Seite.
///
/// Ein Werkzeug, das verspricht, Apps das Netz zu entziehen, muss sagen, was
/// es dafür wirklich tut — sonst hält jemand für gesperrt, was in Wahrheit
/// weiterläuft. Diese Seite verkauft die Grenzen mit, nicht nur die Stärken.
export function Honest() {
  const head = useReveal<HTMLDivElement>()
  const grid = useReveal<HTMLDivElement>(80)
  const table = useReveal<HTMLDivElement>(160)

  return (
    <section id="grenzen">
      <div className="wrap">
        <div className="section-head reveal" ref={head}>
          <span className="eyebrow">Ehrlich gesagt</span>
          <h2>Was es kann — und was nicht</h2>
          <p className="lead">
            macOS bietet ohne Apple-Entitlement keinen Weg, einer einzelnen App nur
            das Netz zu entziehen. Deshalb gestaffelte Hebel — und deshalb steht
            hier, wo jeder aufhört.
          </p>
        </div>

        <div className="honest-grid reveal" ref={grid}>
          <div className="honest can">
            <h3><span aria-hidden>✓</span> Das geht</h3>
            <ul>
              <li><span><b>Verbrauch pro Dienst</b> — über <code className="mono">nettop</code>, ohne Sonderrechte.</span></li>
              <li><span><b>Systemdienste sauber anhalten</b> — <code className="mono">launchctl kill SIGSTOP</code>, vollständig reversibel.</span></li>
              <li><span><b>Netze automatisch erkennen</b> — an der MAC-Adresse des Routers, ohne Ortungsdienste.</span></li>
              <li><span><b>Budget mit Tagesration</b> — samt Hochrechnung und automatischer Eskalation.</span></li>
              <li><span><b>Alles rückgängig machen</b> — Quittung vor dem Eingriff, Aufräumen beim Start.</span></li>
            </ul>
          </div>

          <div className="honest cannot">
            <h3><span aria-hidden>✗</span> Das geht nicht</h3>
            <ul>
              <li><span><b>Einer App nur das Netz nehmen</b> — dafür bräuchte es einen <code className="mono">NEFilterDataProvider</code>, ein von Apple freizugebendes Entitlement und Xcode.</span></li>
              <li><span><b>Abrechnungsgenaue Zahlen</b> — <code className="mono">nettop</code> ist ein Stichprobenverfahren. Prozesse, die zwischen zwei Messungen entstehen und vergehen, fehlen.</span></li>
              <li><span><b>Ohne sudo alles sperren</b> — macOS-Update, iCloud und Time Machine brauchen root. Das Werkzeug sagt das ausdrücklich, statt „Urlaubsmodus aktiv“ zu behaupten.</span></li>
              <li><span><b>CDN-Adressen dauerhaft sperren</b> — die weichen aus. Der PF-Hebel weiß das und schreibt es an die Zeile.</span></li>
            </ul>
          </div>
        </div>

        <div className="card reveal" ref={table} style={{ marginTop: 18, padding: 24 }}>
          <h3 style={{ marginBottom: 4 }}>Die drei Hebel</h3>
          <p style={{ fontSize: '0.86rem', color: 'var(--muted)', marginBottom: 10 }}>
            Für jeden Dienst wird der beste verfügbare genommen — von sauber nach grob.
          </p>
          <table className="lever-table">
            <thead>
              <tr><th>Hebel</th><th>Wirkung</th><th>Rechte</th></tr>
            </thead>
            <tbody>
              <tr>
                <td>Systemdienst anhalten</td>
                <td><code className="mono">launchctl kill SIGSTOP</code> — sauber, vollständig reversibel, stoppt das Volumen an der Quelle</td>
                <td className="accent-amber">root</td>
              </tr>
              <tr>
                <td>Ziel-Adressen sperren</td>
                <td>Eigener PF-Anchor; die App bleibt bedienbar, aber CDN-Adressen können ausweichen</td>
                <td className="accent-amber">root + install-pf</td>
              </tr>
              <tr>
                <td>App einfrieren</td>
                <td><code className="mono">SIGSTOP</code> — friert die <b>ganze</b> App ein, nicht nur ihr Netz. Für Sync-Clients genau richtig, für Browser grob</td>
                <td className="accent-green">keine</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
  )
}
