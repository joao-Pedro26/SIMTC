'use client'

import { X } from 'lucide-react'
import { type ReactNode, useEffect, useState } from 'react'
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

  if (!visible) return null

  function handleClose() {
    setClosing(true)
    setTimeout(() => {
      setVisible(false)
      setClosing(false)
      onClose()
    }, 220)
  }

  return (
    <div className={`${styles.overlay} ${closing ? styles.overlayOut : ''}`} onClick={handleClose}>
      <aside className={`${styles.panel} ${closing ? styles.panelOut : ''}`} style={maxWidth ? { maxWidth } : undefined} onClick={(e) => e.stopPropagation()}>
        <div className={styles.header}>
          <h2 className={styles.title}>{title}</h2>
          <button className={styles.closeBtn} onClick={handleClose} aria-label="Fechar">
            <X size={18} />
          </button>
        </div>
        <div className={styles.content}>
          {children}
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
