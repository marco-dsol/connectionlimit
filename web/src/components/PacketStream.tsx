import { useEffect, useRef, type RefObject } from 'react'

/// Hintergrund des Kopfbereichs: Datenpakete strömen von links auf eine
/// Grenze zu. Die meisten prallen dort ab und verglühen rot — gesperrt. Ab
/// und zu schlüpft eines orange hindurch — der Durchbruch, den die App
/// protokolliert. Dieselbe Farbsprache wie überall: grün bewegt Daten, rot
/// ist gesperrt, orange ist gesperrt und trotzdem unterwegs.
///
/// Bewegung, die etwas bedeutet: Das Bild erzählt in drei Sekunden, was das
/// Werkzeug tut. Es läuft nur, solange es zu sehen ist, und steht still für
/// alle, die reduzierte Bewegung eingestellt haben.

type Fate = 'block' | 'leak'

interface Packet {
  x: number
  y: number
  speed: number
  len: number
  width: number
  fate: Fate
  /// 0 = unterwegs, 1 = an der Grenze verglüht bzw. durchgerutscht.
  phase: 'flow' | 'burn' | 'through'
  age: number
}

interface Impact {
  y: number
  age: number
  leak: boolean
}

const GREEN = '61, 220, 151'
const RED = '255, 95, 86'
const AMBER = '255, 176, 32'
const CHALK = '247, 250, 252'

/// Anteil der Pakete, die trotz Grenze durchkommen. Selten genug, dass es
/// auffällt — genau wie in Wirklichkeit.
const LEAK_RATE = 0.07
const BURN_TIME = 0.55
const IMPACT_TIME = 0.6

export function PacketStream({ anchor }: { anchor: RefObject<HTMLElement | null> }) {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    const host = canvas?.parentElement
    const ctx = canvas?.getContext('2d')
    if (!canvas || !host || !ctx) return

    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    let width = 0
    let height = 0
    let limitX = 0
    let packets: Packet[] = []
    let impacts: Impact[] = []
    let spawnDebt = 0
    let raf = 0
    let last = 0
    let visible = true

    /// Die Grenze steht zwischen Text und Fenster-Nachbau. Liegen beide
    /// untereinander (schmaler Bildschirm), rückt sie an den rechten Rand.
    const measure = () => {
      const dpr = Math.min(2, window.devicePixelRatio || 1)
      const box = host.getBoundingClientRect()
      width = box.width
      height = box.height
      canvas.width = Math.round(width * dpr)
      canvas.height = Math.round(height * dpr)
      canvas.style.width = `${width}px`
      canvas.style.height = `${height}px`
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0)

      const panel = anchor.current?.getBoundingClientRect()
      const sideBySide = panel && panel.top - box.top < height * 0.45 && panel.left - box.left > width * 0.3
      limitX = sideBySide ? panel.left - box.left - 30 : width - 12
    }

    const spawn = (x?: number) => {
      const leak = Math.random() < LEAK_RATE
      packets.push({
        x: x ?? -40 - Math.random() * 80,
        y: height * (0.06 + Math.random() * 0.88),
        speed: 70 + Math.random() * 120,
        len: 14 + Math.random() * 34,
        width: Math.random() < 0.2 ? 2 : 1.2,
        fate: leak ? 'leak' : 'block',
        phase: 'flow',
        age: 0,
      })
    }

    const step = (dt: number) => {
      // Dichte an die Fläche koppeln: Auf dem Telefon wäre derselbe Strom
      // ein Gedränge.
      spawnDebt += dt * Math.max(4, (width * height) / 75000)
      while (spawnDebt >= 1) {
        spawn()
        spawnDebt -= 1
      }

      for (const p of packets) {
        p.age += dt
        if (p.phase === 'flow') {
          p.x += p.speed * dt
          if (p.x >= limitX) {
            p.x = limitX
            p.age = 0
            p.phase = p.fate === 'leak' ? 'through' : 'burn'
            impacts.push({ y: p.y, age: 0, leak: p.fate === 'leak' })
          }
        } else if (p.phase === 'through') {
          p.x += p.speed * 0.5 * dt
        }
      }
      packets = packets.filter((p) =>
        p.phase === 'burn' ? p.age < BURN_TIME
          : p.phase === 'through' ? p.x - p.len < width && p.age < 3.2
          : true)

      for (const i of impacts) i.age += dt
      impacts = impacts.filter((i) => i.age < IMPACT_TIME)
    }

    const draw = () => {
      ctx.clearRect(0, 0, width, height)
      ctx.lineCap = 'round'

      for (const p of packets) {
        if (p.phase === 'flow') {
          // Kurz vor der Grenze wird ein Paket heller — es „sieht“ sie kommen.
          const near = Math.max(0, 1 - (limitX - p.x) / 160)
          stroke(p.x - p.len, p.y, p.x, GREEN, 0.4 + near * 0.4, p.width)
        } else if (p.phase === 'burn') {
          const k = p.age / BURN_TIME
          const len = p.len * (1 - k)
          stroke(p.x - len, p.y, p.x, RED, 0.75 * (1 - k), p.width + 0.6)
          // Funken, die von der Grenze zurückspritzen.
          ctx.fillStyle = `rgba(${RED}, ${0.6 * (1 - k)})`
          for (let s = -1; s <= 1; s += 2) {
            ctx.beginPath()
            ctx.arc(p.x - 10 * k, p.y + s * 9 * k, 1.1, 0, Math.PI * 2)
            ctx.fill()
          }
        } else {
          const fade = Math.max(0, 1 - p.age / 3.2)
          stroke(p.x - p.len, p.y, p.x, AMBER, 0.85 * fade, p.width + 0.4)
        }
      }

      // Die Grenze selbst: eine harte, helle Linie wie im Logo. Wo gerade
      // etwas aufschlägt, glimmt sie kurz auf.
      const line = ctx.createLinearGradient(0, 0, 0, height)
      line.addColorStop(0, `rgba(${CHALK}, 0)`)
      line.addColorStop(0.15, `rgba(${CHALK}, 0.22)`)
      line.addColorStop(0.85, `rgba(${CHALK}, 0.22)`)
      line.addColorStop(1, `rgba(${CHALK}, 0)`)
      ctx.fillStyle = line
      ctx.fillRect(limitX, 0, 1.4, height)

      for (const i of impacts) {
        const k = i.age / IMPACT_TIME
        const color = i.leak ? AMBER : RED
        const glow = ctx.createRadialGradient(limitX, i.y, 0, limitX, i.y, 14 + 14 * k)
        glow.addColorStop(0, `rgba(${color}, ${(i.leak ? 0.45 : 0.24) * (1 - k)})`)
        glow.addColorStop(1, `rgba(${color}, 0)`)
        ctx.fillStyle = glow
        ctx.fillRect(limitX - 30, i.y - 30, 60, 60)
        ctx.fillStyle = `rgba(${CHALK}, ${0.7 * (1 - k)})`
        ctx.fillRect(limitX - 0.4, i.y - 9 * (1 - k * 0.5), 2.2, 18 * (1 - k * 0.5))
      }
    }

    function stroke(x1: number, y: number, x2: number, rgb: string, alpha: number, w: number) {
      const g = ctx!.createLinearGradient(x1, y, x2, y)
      g.addColorStop(0, `rgba(${rgb}, 0)`)
      g.addColorStop(1, `rgba(${rgb}, ${alpha})`)
      ctx!.strokeStyle = g
      ctx!.lineWidth = w
      ctx!.beginPath()
      ctx!.moveTo(x1, y)
      ctx!.lineTo(x2, y)
      ctx!.stroke()
    }

    const frame = (now: number) => {
      raf = 0
      const dt = Math.min(0.05, (now - last) / 1000 || 0)
      last = now
      step(dt)
      draw()
      schedule()
    }

    const schedule = () => {
      if (!raf && visible && !document.hidden && !reduced) {
        raf = window.requestAnimationFrame((now) => {
          last = now
          raf = window.requestAnimationFrame(frame)
        })
      }
    }

    /// Ein Standbild mitten aus dem Geschehen — für reduzierte Bewegung und
    /// als erster Eindruck, bevor die Animation anläuft.
    const prime = () => {
      packets = []
      impacts = []
      const inFlight = Math.max(4, (width * height) / 75000) * (limitX / 130)
      for (let i = 0; i < inFlight; i++) spawn(Math.random() * limitX)
      for (let i = 0; i < 30; i++) step(1 / 30)
      draw()
    }

    measure()
    prime()
    schedule()

    // Neue Maße leeren die Leinwand. Sofort neu zeichnen, statt auf den
    // nächsten Takt zu warten — der kommt in einem Hintergrund-Tab nie.
    const resize = new ResizeObserver(() => {
      measure()
      if (reduced) prime()
      else draw()
    })
    resize.observe(host)

    const io = new IntersectionObserver(([entry]) => {
      visible = entry.isIntersecting
      if (visible) schedule()
      else if (raf) {
        window.cancelAnimationFrame(raf)
        raf = 0
      }
    })
    io.observe(canvas)

    const onVisibility = () => {
      if (document.hidden && raf) {
        window.cancelAnimationFrame(raf)
        raf = 0
      } else schedule()
    }
    document.addEventListener('visibilitychange', onVisibility)

    return () => {
      if (raf) window.cancelAnimationFrame(raf)
      resize.disconnect()
      io.disconnect()
      document.removeEventListener('visibilitychange', onVisibility)
    }
  }, [anchor])

  return <canvas ref={canvasRef} className="packet-stream" aria-hidden />
}
