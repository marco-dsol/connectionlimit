import { useEffect, useRef, type ReactNode } from 'react'

/// Ein Fenster über der Seite. Das native `<dialog>` bringt Fokusfalle,
/// Escape, die oberste Ebene und das Zurückgeben des Fokus von selbst mit —
/// nachbauen ließe sich das nur schlechter.
export function Modal({ open, onClose, label, closeLabel, className, children }: {
  open: boolean
  onClose: () => void
  label: string
  closeLabel: string
  className?: string
  children: ReactNode
}) {
  const ref = useRef<HTMLDialogElement>(null)

  useEffect(() => {
    const dialog = ref.current
    if (!dialog) return
    if (open && !dialog.open) dialog.showModal()
    if (!open && dialog.open) dialog.close()
  }, [open])

  // Escape schließt das Fenster am Zustand vorbei; die Ereignisse holen ihn
  // nach. `cancel` kommt sofort mit dem Tastendruck, `close` erst als eigene
  // Aufgabe danach — und die lässt Chrome in einem Hintergrund-Tab liegen.
  // Also beide; ein doppeltes Schließen schadet nicht.
  useEffect(() => {
    const dialog = ref.current
    if (!dialog) return
    dialog.addEventListener('cancel', onClose)
    dialog.addEventListener('close', onClose)
    return () => {
      dialog.removeEventListener('cancel', onClose)
      dialog.removeEventListener('close', onClose)
    }
  }, [onClose])

  return (
    <dialog
      ref={ref}
      className={className ? `modal ${className}` : 'modal'}
      aria-label={label}
      // Ein Klick neben das Fenster trifft das `<dialog>` selbst, einer
      // hinein immer den Inhalt — so schließt nur der Klick daneben.
      onClick={(event) => event.target === event.currentTarget && onClose()}
    >
      <div className="modal-inner">
        <button type="button" className="modal-close" aria-label={closeLabel} title={closeLabel} onClick={onClose}>
          <svg viewBox="0 0 16 16" width="14" height="14" aria-hidden>
            <path d="M3 3l10 10M13 3L3 13" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
          </svg>
        </button>
        {children}
      </div>
    </dialog>
  )
}
