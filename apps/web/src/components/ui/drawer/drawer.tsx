'use client'

import { X } from 'lucide-react'
import { type ReactNode, useCallback, useEffect, useRef, useState } from 'react'
import { useConfirmUnsaved } from '@/components/ui/confirm-dialog/confirm-dialog-provider'
import { DrawerGuardContext, type DrawerGuard } from './drawer-guard'
import styles from './drawer.module.css'

interface DrawerProps {
  open: boolean
  title: string
  onClose: () => void
  children: ReactNode
  footer?: ReactNode
  /** Largura máxima customizada, ex: '72rem'. Padrão: 46rem */
  maxWidth?: string
}

export function Drawer({ open, title, onClose, children, footer, maxWidth }: DrawerProps) {
  const [visible, setVisible] = useState(false)
  const [closing, setClosing] = useState(false)
  const guard = useRef<DrawerGuard | null>(null)
  const asking = useRef(false)
  const confirmUnsaved = useConfirmUnsaved()

  useEffect(() => {
    if (open) {
      setClosing(false)
      setVisible(true)
    } else if (visible) {
      setClosing(true)
      const timer = setTimeout(() => {
        setVisible(false)
        setClosing(false)
      }, 220)
      return () => clearTimeout(timer)
    }
  }, [open])

  function handleClose() {
    setClosing(true)
    setTimeout(() => {
      setVisible(false)
      setClosing(false)
      onClose()
    }, 220)
  }

  // Clicar fora, X e Esc passam por aqui: com alterações não salvas, pergunta antes.
  const requestClose = useCallback(async () => {
    const current = guard.current
    if (current?.dirty) {
      if (asking.current) return
      asking.current = true
      const choice = await confirmUnsaved()
      asking.current = false
      if (choice === 'cancel') return
      if (choice === 'save') {
        // Quem salva costuma fechar o drawer quando dá certo; se falhar, ele continua aberto.
        // Quem não fecha avisa devolvendo `true`.
        const saved = await current.save()
        if (saved === true) handleClose()
        return
      }
    }
    handleClose()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [confirmUnsaved, onClose])

  useEffect(() => {
    if (!open) return
    function onKeyDown(e: KeyboardEvent) {
      if (e.key !== 'Escape' || e.defaultPrevented) return
      // Outro modal aberto por cima (confirmações, avaliação...) trata o próprio Esc.
      if (document.querySelector('[aria-modal="true"]')) return
      // Sugestões de cidade abertas: o Esc só fecha a lista.
      if ((e.target as HTMLElement | null)?.closest?.('[aria-expanded="true"]')) return
      requestClose()
    }
    document.addEventListener('keydown', onKeyDown)
    return () => document.removeEventListener('keydown', onKeyDown)
  }, [open, requestClose])

  if (!visible) return null

  return (
    <div className={`${styles.overlay} ${closing ? styles.overlayOut : ''}`} onClick={requestClose}>
      <aside className={`${styles.panel} ${closing ? styles.panelOut : ''}`} style={maxWidth ? { maxWidth } : undefined} onClick={(e) => e.stopPropagation()}>
        <div className={styles.header}>
          <h2 className={styles.title}>{title}</h2>
          <button className={styles.closeBtn} onClick={requestClose} aria-label="Fechar">
            <X size={18} />
          </button>
        </div>
        <div className={styles.content}>
          <DrawerGuardContext.Provider value={guard}>
            {children}
          </DrawerGuardContext.Provider>
        </div>
        {footer && (
          <div className={styles.footer}>
            {footer}
          </div>
        )}
      </aside>
    </div>
  )
}
