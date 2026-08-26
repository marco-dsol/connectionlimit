import { useEffect, useState } from 'react'

/// Zählt in festem Takt hoch — die Zeitbasis für alle Simulationen auf dieser
/// Seite. Läuft nur, wenn die Seite sichtbar ist: Ein Timer, der im
/// Hintergrund weiterläuft, verbrennt Akku für nichts.
export function useTicker(intervalMs: number, running = true) {
  const [tick, setTick] = useState(0)

  useEffect(() => {
    if (!running) return
    let id = 0
    const start = () => {
      id = window.setInterval(() => {
        if (!document.hidden) setTick((t) => t + 1)
      }, intervalMs)
    }
    start()
    return () => window.clearInterval(id)
  }, [intervalMs, running])

  return tick
}

/// Weicher Zufall für simulierte Datenraten: Der neue Wert hängt am alten,
/// springt also nicht. Ein rein zufälliger Wert je Takt sähe aus wie Rauschen,
/// nicht wie Datenverkehr.
export function drift(value: number, min: number, max: number, step = 0.28) {
  const delta = (Math.random() - 0.45) * (max - min) * step
  return Math.min(max, Math.max(min, value + delta))
}
