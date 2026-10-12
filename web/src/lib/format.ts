/// Dezimal gerechnet (1 kB = 1000 B) — so rechnen Mobilfunktarife ab, und
/// darum geht es hier. Dieselbe Regel wie in der App.
export function bytes(value: number): string {
  const v = Math.abs(value)
  if (v < 1000) return `${Math.round(value)} B`
  if (v < 1e6) return `${(value / 1e3).toFixed(1)} kB`
  if (v < 1e9) return `${(value / 1e6).toFixed(1)} MB`
  return `${(value / 1e9).toFixed(2)} GB`
}

export function rate(bytesPerSecond: number): string {
  if (bytesPerSecond < 1) return '—'
  return `${bytes(bytesPerSecond)}/s`
}

export function clock(locale: string, date = new Date()): string {
  return date.toLocaleTimeString(locale, { hour: '2-digit', minute: '2-digit', hour12: false })
}
