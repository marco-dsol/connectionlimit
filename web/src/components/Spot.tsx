import { useCallback, useRef, useState } from 'react'
import { Modal } from './Modal'
import { useLang } from '../i18n'

/// Der Werbespot (Fassung 2) hinter einem Knopf. Geladen wird erst beim
/// Öffnen — fünf Megabyte, die niemand bezahlen soll, der nur liest. Und
/// gestartet direkt im Klick: Safari spielt mit Ton nur ab, was der Klick
/// selbst anstößt, nicht etwas, das ein Effekt danach nachreicht.
export function Spot() {
  const { t, lang } = useLang()
  const [open, setOpen] = useState(false)
  const video = useRef<HTMLVideoElement>(null)

  const show = () => {
    setOpen(true)
    video.current?.play().catch(() => {
      /* Abspielen verweigert — die Steuerleiste ist trotzdem da */
    })
  }

  const hide = useCallback(() => {
    setOpen(false)
    video.current?.pause()
  }, [])

  return (
    <>
      <button type="button" className="btn btn-primary btn-play" onClick={show} data-umami-event="video" data-umami-event-lang={lang}>
        <span className="play-icon" aria-hidden>
          <svg viewBox="0 0 12 12" width="11" height="11">
            <path d="M3 1.6v8.8a.6.6 0 0 0 .9.5l7-4.4a.6.6 0 0 0 0-1L3.9 1.1a.6.6 0 0 0-.9.5z" fill="currentColor" />
          </svg>
        </span>
        {t.spot.cta}
        <span className="play-length">{t.spot.length}</span>
      </button>

      <Modal open={open} onClose={hide} label={t.spot.title} closeLabel={t.legal.close} className="modal-video">
        {/* `key`: Beim Sprachwechsel ein frisches Element, sonst liefe der
            alte Ton unter der neuen Quelle weiter. */}
        <video
          key={lang}
          ref={video}
          src={`./video/connectionlimit-spot-${lang}.mp4`}
          poster={`./video/connectionlimit-spot-${lang}.jpg`}
          controls
          playsInline
          preload="none"
        >
          {t.spot.fallback}
        </video>
        <div className="spot-caption">
          <span>{t.spot.title} · {t.spot.length}</span>
          <span>{t.spot.ai}</span>
        </div>
      </Modal>
    </>
  )
}
