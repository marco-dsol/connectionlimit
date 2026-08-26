import { useEffect, useRef } from 'react'

/// Blendet ein Element ein, sobald es ins Bild kommt — einmal, nicht bei
/// jedem Vorbeiscrollen. Wiederholte Bewegung beim Zurückscrollen wirkt
/// nervös und trägt keine Information.
export function useReveal<T extends HTMLElement>(delay = 0) {
  const ref = useRef<T>(null)

  useEffect(() => {
    const node = ref.current
    if (!node) return
    node.style.transitionDelay = `${delay}ms`

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          node.classList.add('in')
          observer.disconnect()
        }
      },
      { threshold: 0.14, rootMargin: '0px 0px -60px 0px' },
    )
    observer.observe(node)
    return () => observer.disconnect()
  }, [delay])

  return ref
}
